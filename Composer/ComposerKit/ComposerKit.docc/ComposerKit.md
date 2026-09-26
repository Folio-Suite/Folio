# ``ComposerKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

The domain framework for Folio Composer's Arrangements, including Editions.

## Overview

ComposerKit is currently a framework skeleton. It links to FolioKit but does not
yet expose Arrangement editing, composition, or Rendition generation APIs.

The Composer application currently hosts its provisional document and storyboard
directly. As Arrangement behavior is implemented, its public domain operations and
reusable presentation belong here, with persistence details kept behind the
framework interface. An Edition is a self-contained production Arrangement with
pinned content and retained dependencies. Its editorial identity is independent
of medium; named Production Configurations govern its output presentation.
An Edition is distinct from the complete archival folio and generated Renditions.

The adopted composition design places a native engine here, independently callable
by UI and automation. It derives medium-specific compositions from a shared
Publication Plan, using Profiles for construction and layout and Themes for
appearance and typography. Coordinated Streams, paragraph composition, and output
generation remain implementation and experiment work, not current APIs.

### Public interface and hosting

Import `<ComposerKit/ComposerKit.h>` or use `@import ComposerKit;`. The owning application
uses this same interface as other hosts. Only the headers enumerated in the Kit's
module map are supported; other headers are private implementation. Apps and Kits ship as a coordinated Suite version. Mixed versions
are unsupported; this documentation does not promise independent binary compatibility.
