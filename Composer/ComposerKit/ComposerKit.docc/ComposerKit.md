# ``ComposerKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

The domain framework for Folio Composer's Edition capabilities.

## Overview

ComposerKit is currently a framework skeleton. It links to FolioKit but does not
yet expose Edition editing, composition, or Rendition generation APIs.

The Composer application currently hosts its provisional document and storyboard
directly. As Edition behavior is implemented, its public domain operations and
reusable presentation belong here, with persistence details kept behind the
framework interface. An Edition is a publication configuration; it is distinct
from the complete archival folio and from generated Renditions.

### Public interface and hosting

Import `<ComposerKit/ComposerKit.h>` or use `@import ComposerKit;`. The owning application
uses this same interface as other hosts. Only the headers enumerated in the Kit's
module map are supported; embedded libraries and other headers are private
implementation. Apps and Kits ship as a coordinated Suite version. Mixed versions
are unsupported; this documentation does not promise independent binary compatibility.
