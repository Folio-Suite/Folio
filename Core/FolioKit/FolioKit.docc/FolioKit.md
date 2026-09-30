# ``FolioKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Shared foundations used by Folio's domain frameworks.

## Overview

FolioKit provides stable identity, immutable authored-text values, and temporary package staging through a public Swift module. Its model types use Foundation and keep authored meaning separate from visual presentation. They do not depend on AppKit or Core Data.

## Current support

The text model includes identities, Manuscript reading order, text Content Units, paragraphs, runs, semantic emphasis, and independent presentation flags. ``FolioIdentifier`` rejects empty identifiers. ``TextUnit`` and ``Manuscript`` reject empty collections, and a Manuscript rejects duplicate Content Unit identities. Replacing text snapshots can preserve their identities and Content Unit warning-dismissal state.

``PackageStaging`` runs a synchronous throwing operation in a unique temporary directory and removes that directory after success or failure. Callers must return results that do not depend on the temporary files remaining.

## Public interface and hosting

Swift callers use `import FolioKit`. The model and staging implementations have no transitional Objective-C adapters. Apps and Kits ship as a coordinated Suite version; mixed versions are unsupported, and independent binary compatibility is not promised.

The public declarations and their DocC comments are in `Interface/FolioValues.swift`
and `Interface/PackageStaging.swift`.

## Limitations

FolioKit supplies shared model foundations, not Work persistence, Source Library behavior, Arrangement behavior, or reusable AppKit editing. XML exchange is not implemented. The authored-text model does not contain editor selection or undo-manager state.

## Topics

### Authored text

- ``FolioIdentifier``
- ``FolioValueError``
- ``Manuscript``
- ``TextUnit``
- ``TextParagraph``
- ``TextRun``
- ``TextEmphasis``
- ``TextPresentation``
- ``ParagraphAlignment``

### Package staging

- ``PackageStaging``

### Text semantics and appearance

``TextRun/emphasis`` is one exclusive ``TextEmphasis`` category. ``TextRun/presentation`` stores independent bold, italic, underline, and strikethrough values; neither is inferred from the other. Renderers choose how semantic categories look. ``TextUnit/formattingWarningDismissed`` belongs to the Content Unit and can be preserved when creating a replacement text snapshot.

### Manuscript order

``Manuscript`` is an immutable reading-order snapshot of text Content Units. ``TextUnit/title`` labels a unit independently of its authored words. Replacements retain identities; selection and undo managers remain outside these Foundation values.
