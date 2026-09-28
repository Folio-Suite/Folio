<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Centralize the Folio domain framework targets

FolioKit, WriteKit, ResearchKit, and ComposerKit are built as separate framework targets in `Core/Core.xcodeproj`, with their sources and unit tests under `Core/`. Application projects retain applications, services, and app/UI tests, and link the four frameworks. This gives every app the same common capability foundation while preserving domain ownership; app-specific workflows build above it, with deeper professional tools following later. TypographyKit and UndoKit remain standalone independent frameworks for possible future reuse. This structural work does not start the accepted Swift migration or establish sandbox or App Store support.
