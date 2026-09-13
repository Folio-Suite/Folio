# ``ResearchKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Source Library package support for Folio Research.

## Overview

``FRLibraryPackage`` creates an empty native Source Library package and validates
its catalog store. The Research application owns document hosting and preserves
additional package members across saves. Source catalog editing and cross-app
service operations remain future work.

### Public interface and hosting

Import `<ResearchKit/ResearchKit.h>` or use `@import ResearchKit;`. The owning application
uses this same interface as other hosts. Only the headers enumerated in the Kit's
module map are supported; other headers are private implementation. Apps and Kits ship as a coordinated Suite version. Mixed versions
are unsupported; this documentation does not promise independent binary compatibility.

## Topics

### Native packages

- ``FRLibraryPackage``