<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Swift migration baseline

Baseline captured at `b50fa0023848d0f81961b7c85df924af3917eb1a` (2026-09-28), before production migration work, for [M0 / issue #31](https://github.com/Folio-Suite/Folio/issues/31).

## Production inventory

The tracked tree contains 45 Objective-C implementation files (`.m`), 28 Objective-C headers (`.h`), five Swift files, four storyboards, and six versioned Core Data model files. Counts include production, test, and prototype sources; they are a locator inventory, not a migration completion metric. Production Objective-C remains in the three app targets, their XPC service targets, and FolioKit, WriteKit, ResearchKit, and ComposerKit. The checked-in Swift is limited to the TypographyKit scaffold and small interface-check/probe sources; TypographyKit currently exposes no composition behavior.

The applications remain Write, Research, and Composer. AppKit document controllers, storyboards, Core Data, Core Text, XPC services, package/document type declarations, and localization resources are part of the migration surface. The principal models are `Core/WriteKit/Resources/FWWork.xcdatamodeld`, `Research/Research/FRDocument.xcdatamodeld`, and `Composer/Composer/Document.xcdatamodeld`. Their existence does not establish schema compatibility after migration; M2–M5 and the acceptance slice must check actual saved documents.

## Existing verification seams

The accepted specification confirms two existing seams: public Kit interfaces for domain values, packages, and editor behavior; and native document/UI workflows for hosting, resources, focus, menus, Undo, saving, and accessibility. TypographyKit work will add one public composition interface over immutable inputs/results, source mappings, and diagnostics. Tests should exercise these seams and independently derive expected results rather than add public test-only hooks. See [accepted-backlog specification coverage](../plans/accepted-backlog.md#specification-coverage), which maps each of stories 1–53 to owning slices.

Current concrete examples:

- `Write/WriteTests/WriteTests.m` creates a Work through the current writer, checks `.flwrbundle` type/package identity, reopens it, and checks text, bold presentation, Content Unit identity, and title.
- `Research/ResearchTests/ResearchTests.m` creates a Research package, checks `.flrsbundle` identity, preserves an added asset across save/save-as, and checks that invalid packages do not replace an open Library.
- Kit unit tests live under `Core/*KitTests/`; app interaction tests live under each app's `*UITests/`; localization, packaging, release, and CI helper tests live under `scripts/tests/`.

The checked-in synthetic fixtures in [`tests/fixtures/swift-migration-baseline`](../../tests/fixtures/swift-migration-baseline/README.md) were captured from the baseline writer. The Work package covers identity, ordered paragraphs, Unicode, formatting, title, and warning preference; the Research package covers the empty catalog shell and a collected asset. The fixture README records provenance and regeneration guidance.

## Typography evidence and provenance

Typography work already has reproducible, checked-in native comparison evidence under `Composer/Prototypes/ParagraphComposition/`: source specimens and font notes, Core Text and TextKit 2 drivers/results, JSON run records, and rendered images. The narrower `Controls/` experiment includes findings, result data, and evidence for expansion and punctuation behavior. Research and interpretation are documented in `docs/research/2026-09-26-native-paragraph-composition.md` and `docs/research/2026-09-27-textkit2-hyphenation-and-composition-controls.md`; the accepted roadmap retains the paragraph probe as completed evidence. Preserve these paths and provenance during migration. They are historical experiments, not production TypographyKit behavior or a substitute for the new public-interface acceptance criteria.

## Platform and execution evidence

The signed baseline Suite build passed at the recorded commit, and the public interface checks passed. Ruby tooling reported 17 tests and 98 assertions passing. The signed native Folio test plan passed on macOS 27 / Apple Silicon: 42 tests, 105 executions, no failures or skips. The completed Xcode result bundle confirmed the full result after the tool summary omitted some test results. Sonoma and Intel runtime checks remain unrun.

## Migration use

Use this inventory and the baseline-writer packages for M1–M5 and I1. The maintainer has stated this is a pre-alpha product with no valuable user data and accepts breakage during migration; the accepted stories and compatibility checks remain the migration contract.
