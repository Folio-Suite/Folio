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
