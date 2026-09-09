<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# ``FolioKit``

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
