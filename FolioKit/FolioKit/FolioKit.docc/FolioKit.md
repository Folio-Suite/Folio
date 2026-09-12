# ``FolioKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Shared foundations for Folio's domain frameworks.

## Overview

The initial text vocabulary uses immutable Foundation objects. Text meaning is independent of its appearance, and paragraphs retain stable identities through editing and persistence. These types can carry authored text in Write or commentary in Research without depending on AppKit or Core Data.

The `FKModelFoundations` dynamic library implements these text primitives. `FKPackageSupport` owns temporary package staging and cleanup, without knowing any domain schema. FolioKit publishes their public headers and re-exports the libraries; callers import FolioKit. Headers remain beside their implementation files. `FKXMLSupport` is still reserved for future exchange work.

## Topics

### Authored text

- ``FKIdentifiedObject``
- ``FKText``
- ``FKParagraph``
- ``FKTextRun``

### Package staging

- ``FKPackageSupport``

## Authored text styling

`FKTextRun.emphasis` is one exclusive `FKTextEmphasis` category. `FKTextRun.presentation` is an immutable `FKTextPresentation` with independent `bold`, `italic`, `underline`, and `strikethrough` booleans. Neither property is inferred from the other. Renderers choose the visual idiom for semantic categories. `FKText.formattingWarningDismissed` belongs to the Content Unit and is preserved when creating replacement text snapshots through the initializer that accepts that flag.

### Manuscript order

``FKManuscript`` is an immutable reading-order snapshot of text Content Units. ``FKText/title`` labels a unit independently of its authored words. Replacements retain identities; editor selection and undo managers never enter these Foundation-only objects.
