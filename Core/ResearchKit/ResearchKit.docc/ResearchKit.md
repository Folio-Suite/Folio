# ``ResearchKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Native Source Library package support for Folio Research.

## Overview

ResearchKit owns the domain framework boundary for Source Library behavior and its reusable window scene. The Research application hosts the native document and currently preserves package members when saving.

## Current support

``ResearchLibraryPackage`` creates an empty native Source Library package and validates its catalog store. Validation permits additional package members, rejects live SQLite sidecars, and checks the catalog model version. The host retains the complete wrapper to preserve those additional members. ``ResearchLibraryWindow`` loads the placeholder Source Library window from ResearchKit's `Library.storyboard` on the main actor. This supports the current Research shell; it does not populate or edit a Source catalog.

## Public interface and hosting

Swift callers import `ResearchKit` and use its public package and window APIs. Hosts call ``ResearchLibraryWindow/makeWindowController()`` and attach the returned controller to their document. The owning application uses the same public interface as other hosts. Apps and Kits ship as a coordinated Suite version; mixed versions are unsupported, and independent binary compatibility is not promised.

The public declarations and their DocC comments are in
`Interface/ResearchLibraryPackage.swift` and `Interface/ResearchLibraryWindow.swift`.

## Host the shell in a document

An AppKit host calls the window factory from its `NSDocument.makeWindowControllers()`
override. Registering the returned controller associates that window with the document;
the factory itself does not create, open, or register a document.

```swift
import AppKit
import ResearchKit

@MainActor
final class LibraryDocument: NSDocument {
    override func makeWindowControllers() {
        addWindowController(ResearchLibraryWindow.makeWindowController())
    }
}
```

This fragment covers window hosting only. A document host must also register its
file type and document class, implement reading and saving, and retain the package.
Use ``ResearchLibraryPackage/empty()`` for a new shell and
``ResearchLibraryPackage/validate(_:)`` before accepting an opened package. Validation
checks the catalog metadata, not arbitrary additional members or a populated Source catalog.

## Limitations

Source catalog editing and cross-application service operations are not implemented. The package helper does not provide Source Record capture, enrichment, reconciliation, or synchronization APIs. These capabilities remain future work.

## Topics

### Native packages

- ``ResearchLibraryPackage``
- ``ResearchLibraryWindow``
