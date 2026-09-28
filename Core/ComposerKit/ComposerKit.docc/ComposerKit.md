# ``ComposerKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

The domain framework for Folio Composer's Arrangements, including Editions.

## Overview

ComposerKit is the intended owner of Arrangement and Edition meaning, publication inputs, and publication orchestration. An Edition is a self-contained production Arrangement with pinned content and retained dependencies. Its editorial identity is independent of medium; named Production Configurations govern its output presentation. An Edition is distinct from the complete archival folio and from generated Renditions.

For text composition, ComposerKit will adapt Publication Plans, Profiles, Themes, and coordinated Stream meaning to the independent TypographyKit interface. TypographyKit owns neutral text composition and returns typography results; ComposerKit interprets those results within publication semantics. This division preserves TypographyKit's independence from Folio domain models.

## Current support

ComposerKit is a framework scaffold. Its public Swift module has no Arrangement editing, publication, text-composition, or Rendition-generation API. The Composer application currently hosts its provisional document and storyboard directly.

## Public interface and hosting

Swift callers use `import ComposerKit`. The Cocoa umbrella retains framework identity and version symbols. There are no public domain operations to call. Apps and Kits ship as a coordinated Suite version; mixed versions are unsupported, and independent binary compatibility is not promised.

## Limitations

Arrangement persistence and editing are not implemented. ComposerKit does not own or implement TypographyKit's text-composition engine; its future role is to adapt publication meaning to that independent framework and coordinate its results. Coordinated Streams, paragraph composition, output generation, and reusable Composer presentation remain design or implementation work, not current APIs.
