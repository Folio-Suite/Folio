# ``FolioKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Shared foundations used by Folio's domain frameworks.

## Overview

FolioKit provides stable identity, immutable authored-text values, and temporary package staging. Its model types use Foundation and keep authored meaning separate from visual presentation. They do not depend on AppKit or Core Data.

## Current support

The text model includes identities, Manuscript reading order, text Content Units, paragraphs, runs, semantic emphasis, and independent presentation flags. Replacing text snapshots can preserve their identities and Content Unit warning-dismissal state.

``FKPackageSupport`` runs a synchronous operation in a unique temporary directory and removes that directory after success, failure, or an exception. Callers must return results that do not depend on the temporary files remaining.

## Public interface and hosting

Objective-C callers import `<FolioKit/FolioKit.h>` or use `@import FolioKit;`. Domain frameworks, applications, and other hosts use the same public interface. Only headers listed by FolioKit's module map are supported. Apps and Kits ship as a coordinated Suite version; mixed versions are unsupported, and independent binary compatibility is not promised.

## Limitations

FolioKit supplies shared model foundations, not Work persistence, Source Library behavior, Arrangement behavior, or reusable AppKit editing. `FKXMLSupport` is an empty placeholder; XML exchange is not implemented. The authored-text model does not contain editor selection or undo-manager state.

## Topics

### Authored text

- ``FKIdentifiedObject``
- ``FKManuscript``
- ``FKText``
- ``FKParagraph``
- ``FKTextRun``
- ``FKTextPresentation``

### Package staging

- ``FKPackageSupport``

### Text semantics and appearance

``FKTextRun/emphasis`` is one exclusive ``FKTextEmphasis`` category. ``FKTextRun/presentation`` stores independent bold, italic, underline, and strikethrough values; neither is inferred from the other. Renderers choose how semantic categories look. ``FKText/formattingWarningDismissed`` belongs to the Content Unit and can be preserved when creating replacement text snapshots through the initializer that accepts that flag.

### Manuscript order

``FKManuscript`` is an immutable reading-order snapshot of text Content Units. ``FKText/title`` labels a unit independently of its authored words. Replacements retain identities; selection and undo managers remain outside these Foundation values.
