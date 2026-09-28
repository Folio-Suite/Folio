# ``WriteKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Write's Work model, native editor, and persistence boundary.

## Overview

WriteKit owns supported Work and Manuscript behavior, private Core Data package persistence, and reusable AppKit editing. The Write application hosts the document lifecycle, saving, and the document's shared undo manager.

## Current support

``FWWork`` reads and writes the current native Core Data package and exposes an immutable Manuscript snapshot. A Manuscript contains a flat, ordered list of text Content Units. ``FWManuscriptViewController`` provides a sidebar and retained per-unit editors. ``FWEditorViewController`` edits text and formatting on the main thread, and routes native typing and semantic formatting through the host's undo manager.

The editor supports semantic emphasis categories separately from explicit bold, italic, underline, and strikethrough. It provides formatting-conflict warnings, conversion and dismissal actions, and internal copy/paste that preserves supported formatting with independent text identities. External paste imports plain text.

### Embed the Manuscript editor

Create and use the editor on the main thread. Supply the document's undo manager so native typing and semantic formatting share its undo history.

```objective-c
FWWork *work = [FWWork new];
FWManuscriptViewController *editor = [[FWManuscriptViewController alloc]
    initWithWork:work undoManager:document.undoManager];
NSWindowController *windowController = [editor makeWindowController];
[document addWindowController:windowController];
```

The editor loads its interface from WriteKit's bundled `Editor.storyboard`; the host does not provide a storyboard or construct the controls. The host supplies saving and edited-state tracking through ``FWManuscriptViewController/workDidChange``. Capture the host weakly in that callback. Save with ``FWWork/fileWrapperWithError:`` and handle the returned error; producing an in-memory package does not write a destination file.

### Formatting behavior

The italic E and bold E toolbar controls apply semantic Emphasis and Strong Emphasis. Option-click applies explicit Italic or Bold. The Format menu provides the same actions: Command-I/B applies semantic formatting, and Option-Command-I/B applies explicit formatting. Clear Formatting removes semantic and explicit character formatting while preserving paragraph alignment.

The Appearance popover provides independent Bold, Italic, Underline, and Strikethrough controls with on, off, and mixed states. Strikethrough preserves authored text and does not create a Proposed Revision. Formatting presentation survives native saving and internal copy/paste.

Semantic Emphasis is exclusive: None, Emphasis, Strong Emphasis, or Very Strong Emphasis. Explicit presentation survives semantic changes. Conflicting Bold/Italic presentation receives temporary highlighting and an inline warning. Conversion preserves words and decorations; dismissal is stored per Content Unit and can be undone. These diagnostics are editor-only and do not become authored text.

## Public interface and hosting

Objective-C callers import `<WriteKit/WriteKit.h>` or use `@import WriteKit;`. The owning application uses this same interface as other hosts. Only headers listed by WriteKit's module map are supported. Apps and Kits ship as a coordinated Suite version; mixed versions are unsupported, and independent binary compatibility is not promised.

## Limitations

The Manuscript supports a flat list of text Content Units. Adding, renaming, and reordering are undoable; selection is transient. Nested and unplaced units are unsupported. The host must resolve pending edits and manage undo history before replacing a Work. The current in-process package adapter does not provide shared Work Session recovery or archival folio export. The interface is evolving and has no independent compatibility guarantee.

## Topics

### Authoring

- ``FWWork``
- ``FWEditorViewController``
- ``FWManuscriptViewController``
