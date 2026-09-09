<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# ``WriteKit``

Write's authoring model, native editor, and persistence boundary.

## Overview

``FWWork`` holds an authored text snapshot and reads or writes a native Core Data package. ``FWEditorViewController`` renders and edits that Work with AppKit. The application supplies its NSDocument undo manager and tracks changes through the editor's callback.

The `FWManuscript` dynamic library implements ``FWWork`` and its private Core Data store adapter. `FWEditor` implements ``FWEditorViewController`` and the text-system adapter. WriteKit publishes the public headers from those libraries and re-exports their symbols, so the application continues importing WriteKit. Headers stay beside their implementations.

The package implementation is private to WriteKit. Moving persistence into a separate domain executable should not require the editor to know Core Data's storage layout.

## Topics

### Authoring

- ``FWWork``
- ``FWEditorViewController``
