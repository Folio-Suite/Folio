# ``WriteKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Write's authoring model, native editor, and persistence boundary.

## Overview

``FWWork`` holds an immutable Manuscript snapshot and reads or writes a native Core Data package. ``FWManuscriptViewController`` provides the sidebar and a retained ``FWEditorViewController`` for each visited Content Unit. The application supplies its NSDocument undo manager and tracks changes through ``FWManuscriptViewController/workDidChange``.

### Embed a Manuscript

Create and use the editor on the main thread. Supply the document's undo manager
so native typing and semantic formatting participate in the same undo history.

```objective-c
FWWork *work = [FWWork new];
FWManuscriptViewController *editor = [[FWManuscriptViewController alloc]
    initWithWork:work undoManager:document.undoManager];
NSWindowController *windowController = [editor makeWindowController];
[document addWindowController:windowController];
```

The editor loads its interface from WriteKit’s bundled `Editor.storyboard`.
The host does not need to provide a storyboard or construct its controls.
``FWManuscriptViewController/makeWindowController`` loads the window and native toolbar
from that resource. Embedding the editor view directly provides a text surface
without the window toolbar.

The host supplies document saving and edited-state tracking through
``FWManuscriptViewController/workDidChange``. Capture the host weakly in that callback.
Save with ``FWWork/fileWrapperWithError:`` and check the returned error; producing
an in-memory package does not itself write a destination file.

### Formatting

The native toolbar’s italic E and bold E template icons apply semantic Emphasis and Strong Emphasis.
Their on/off/mixed states describe semantic formatting, independently of explicit
font choices. Option-click applies explicit Italic or Bold. The Format menu also
offers these actions: Command-I/B applies semantic formatting, and
Option-Command-I/B applies explicit formatting. Tooltips and the help popover
explain the distinction. Clear removes both kinds of character formatting while
preserving paragraph alignment.

The semantic Emphasis controls lead the toolbar. The Appearance (BIU) popover offers independent Bold, Italic, Underline, and Strikethrough checkboxes with on, off, and mixed states. Strikethrough retains authored text and does not create a Proposed Revision. These appearance choices survive native saving and internal copy/paste; Clear Formatting removes them.

Emphasis is exclusive: None, Emphasis, Strong Emphasis, or Very Strong Emphasis. Explicit presentation survives semantic changes. Conflicting Bold/Italic presentation receives temporary yellow highlighting and a clickable inline warning marker. The marker opens a popover offering conversion or dismissal. These editor-only diagnostics never become authored text. Conversion preserves words and decorations; dismissal is stored per Content Unit and can be undone. See ``FWEditorViewController/convertPresentationToEmphasis:`` and ``FWEditorViewController/dismissFormattingWarning:``.

### Current limits

The Manuscript supports a flat list of text Content Units. Add, rename, and reorder are undoable; selection is transient. Each unit retains its own editor while sharing chronological document undo, which reveals the unit being changed. Nested and unplaced units are not yet supported. Work replacement requires the host to
resolve pending edits and manage undo history. The in-process package adapter
does not implement shared Work Session recovery or archival folio export. The
current interfaces are evolving and do not carry a compatibility guarantee.

### Public interface and hosting

Import `<WriteKit/WriteKit.h>` or use `@import WriteKit;`. The owning application
uses this same interface as other hosts. Only the headers enumerated in the Kit's
module map are supported; embedded libraries and other headers are private
implementation. Apps and Kits ship as a coordinated Suite version. Mixed versions
are unsupported; this documentation does not promise independent binary compatibility.

## Topics

### Authoring

- ``FWWork``
- ``FWEditorViewController``
- ``FWManuscriptViewController``
