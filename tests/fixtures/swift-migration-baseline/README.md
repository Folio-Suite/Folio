<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Swift migration baseline packages

These synthetic packages were written by the pre-migration Folio writer at `b50fa0023848d0f81961b7c85df924af3917eb1a` on 2026-09-28. They contain no personal data.

- `Baseline.flwrbundle` exercises Work identity, ordered paragraphs, authored Unicode, emphasis/presentation, title, and a persisted warning preference.
- `Baseline.flrsbundle` contains the current empty Research catalog shell plus a collected UTF-8 asset.

The packages were generated and validated through the baseline `FWWork` and `FRLibraryPackage` public APIs with `scripts/capture-migration-baseline-fixtures.m`. To regenerate against a baseline build, compile that source with Cocoa and the `FolioKit`, `WriteKit`, and `ResearchKit` frameworks from the build products, then run it with `DYLD_FRAMEWORK_PATH` set to the framework directory and this directory as its argument. Regeneration assigns new stable object identifiers, so compare package semantics rather than SQLite bytes. The generator writes into the supplied directory and expects it to be empty.

These fixtures preserve a baseline-writer package contract for migration checks. They do not establish broad historical-version compatibility or installed-product behavior.
