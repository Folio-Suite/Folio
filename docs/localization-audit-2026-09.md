<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Localization preparation audit — September 2026

Scope: all three applications, four Kits, three XPC service source trees, four
storyboards, and three application metadata catalogs. Reviewed on 2026-09-24,
using Xcode 27. English remains the source language; no translations were added.

Subsequent translation pass, also on 2026-09-24: the owner authorized initial
translations as a courtesy, with plain American English as the source. All ten
configured target languages now have 465 translated entries each, marked
`needs_review`. This replaces the copied English Arabic entries noted below.
The owner also approved localizing application names in Chinese, Korean, and
Arabic while retaining Folio and the English names in Japanese and European
languages. See `localization.md` for the names and current policy; the findings
below describe the preceding source audit.

Translation validation: all ten nonempty catalogs compiled with `xcstringstool`;
all 4,650 target-language values matched their compiled `.strings` entries
exactly, including entries in `needs_review` state. A Foundation `NSBundle`
lookup returned a compiled French review-state probe at runtime. The clean
unsigned Suite build, Kit interface checks, and bundle-identity checks passed in
a temporary copy. Extraction verification and the four Ruby localization-tool
tests also passed. This confirms resource compilation and review-state display,
not exhaustive translated UI layout or human linguistic review. No translations
were promoted to `translated` merely to make them display.

## Inventory and findings

- All four projects use English development regions and the agreed eleven-language
  roster. There are 417 storyboard entries, 39 distinct code entries after the
  context split, and 12 application metadata entries. Empty catalogs do not imply
  translation coverage. No count-bearing localized format messages currently
  require plural forms.
- Reviewed production Objective-C literals: visible labels, help, undo actions,
  and error messages use localization macros in the owning bundle. Remaining
  literals describe identifiers, filenames, model keys, fonts, or serialization.
  Current service skeletons contain no visible text. No Swift or XIB localization
  sources were found in the component trees.
- The old extractor omitted headers, Objective-C++, and service sources; it also
  accepted obsolete translator comments. Those gaps are repaired. Storyboard
  comments now include ancestor menu/scene context and source wording while
  preserving object IDs, keys, and connections.
- Three shared accessibility/undo contexts were split into separate keys without
  changing English wording: Emphasis, Strong Emphasis, and Add Content Unit.
- Composer had 133 Arabic entries identical to English, marked translated.
  Their text is retained and their state is now `needs_review`. Brand strings
  within that set may legitimately remain unchanged; a language review must
  distinguish them from untranslated prose.
- Application bundle/display names explicitly opt out of translation. Metadata
  document-type names match the declarations in the three Info.plist files;
  descriptive type words remain translatable, and copyright context preserves
  attribution. Metadata is manually audited, not covered by source extraction.
- Catalog refresh now refuses to flatten structured English entries and marks
  nested translated variants for review when a plain English source changes.
  This prevents data loss when plural support is first introduced; structured
  source authoring still requires a deliberate workflow.
- Localized default titles are created once; the store persists and reloads
  authored titles directly. UI-language changes must not rewrite them. A new
  mixed-script package regression covers Arabic, Hebrew, Japanese, Korean,
  decomposed accents, emoji, and natural alignment. It is not a language-switch
  or text-input-method test.

## Validation

- Final read-only extraction check passed for all 39 code and 417 storyboard
  entries after the native test build.
- Ruby localization-tool tests: 4 passed, 15 assertions. These cover translation
  preservation, stale entries, comment drift, source discovery, and plural safety.
- Xcode-managed Write Test action on macOS 27: 33 passed, zero failures or skips,
  including the new mixed-script round trip and existing native document/editor/UI
  regressions. Result bundle:
  `/var/folders/l6/1jrtzdgs4xz0bb5pdz8mgknh0000gn/T/ActionArtifacts/default/RunAllTests/Test-Write-2026.09.24_10-25-33--0500.xcresult`.
- `git diff --check` passed. Existing build-number and FolioKit-scheme edits were
  preserved; no commit or push was made.

## Remaining preparation checks

These remain acceptance work before expanding the editor's UI, not a claim of
completed localization or translated layout quality:

1. Exercise expanded pseudo-localization in the formatting Help, Appearance,
   and conflict popovers, and the paragraph alignment control. The conflict
   popover has a fixed 380-by-170 layout and the alignment control is 118 points
   wide; treat them as concrete truncation/expansion risks. Use intrinsic sizing,
   wrapping, and leading/trailing constraints where measured failures require it.
2. Exercise an Arabic UI with mixed-direction authored text: sidebar mirroring,
   selection, cursor movement, drag, natural versus explicit alignment, undo,
   and save/reopen. Do not mirror document content based on UI language.
3. Repeat the incomplete-translation fallback and cross-process UI-language
   switch probes from the earlier foundation work against current built products.
   Historical evidence in `localization.md` is not fresh acceptance evidence.
4. Use the new macOS 27 VoiceOver automation to inspect focus order and spoken
   editor/sidebar/toolbar names; checking accessibility labels alone is insufficient.
5. Review target-language terminology with language-competent reviewers before
   promoting translations, including the distinction between semantic emphasis
   and visual formatting. Review shortcuts per keyboard layout separately from
   translating their visible descriptions.

The editor's fixed Times New Roman presentation and Latin-oriented emphasis
appearance also warrant script-sensitive presentation review before promising
equivalent typography across authored languages. No typography policy was changed
in this audit.
