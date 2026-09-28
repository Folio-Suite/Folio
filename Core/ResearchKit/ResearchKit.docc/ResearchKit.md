# ``ResearchKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Native Source Library package support for Folio Research.

## Overview

ResearchKit owns the domain framework boundary for Source Library behavior. The Research application hosts the native document and currently preserves package members when saving.

## Current support

``FRLibraryPackage`` creates an empty native Source Library package and validates its catalog store. This supports the current Research shell; it does not populate or edit a Source catalog.

## Public interface and hosting

Objective-C callers import `<ResearchKit/ResearchKit.h>` or use `@import ResearchKit;`. The owning application uses the same public interface as other hosts. Only headers listed by ResearchKit's module map are supported. Apps and Kits ship as a coordinated Suite version; mixed versions are unsupported, and independent binary compatibility is not promised.

## Limitations

Source catalog editing and cross-application service operations are not implemented. The package helper does not provide Source Record capture, enrichment, reconciliation, or synchronization APIs. These capabilities remain future work.

## Topics

### Native packages

- ``FRLibraryPackage``
