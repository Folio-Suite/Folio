<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Localization

English is the development language. The Suite is configured for English, Spanish, French, German, Japanese, Simplified Chinese, Brazilian Portuguese, Traditional Chinese, Korean, Italian, and Arabic. The catalogs currently establish the English source; configuration does not mean the other languages are translated.

## Code strings

Use `NSLocalizedStringWithDefaultValue` with a stable, descriptive key, literal English fallback, and a translator comment. Name the intent, such as `work-package.read.error` or `manuscript.rename-content-unit.undo`, rather than using the English sentence as the key. Separate meanings even when their English spelling matches. Give AppKit the action name for undo; do not construct an English “Undo …” sentence.

Resolve strings from the owning framework's bundle (`dev.foliosuite.FolioKit`, `dev.foliosuite.WriteKit`, or `dev.foliosuite.ResearchKit`). Classes in private dylibs do not own the resource catalogs; do not infer a resource bundle from their class or assume the application's main bundle. Application-owned strings use their app bundle.

Keep filenames, model attributes, format identifiers, action selectors, and accessibility identifiers stable and untranslated. Localize accessible labels and help. A new Content Unit gets its default title in the current language at creation; subsequently that title is authored data and must survive language changes unchanged.

For new count-bearing messages, use catalog plural variations and localized formatting. Keep full sentences together with reorderable placeholders, and explain each placeholder to translators. Do not concatenate translated fragments.

## Interface Builder and metadata

Menus remain in each application's `Base.lproj/Main.storyboard`. The editor's scenes remain in WriteKit's `Resources/Base.lproj/Editor.storyboard`. Their `mul.lproj/Main.xcstrings` and `mul.lproj/Editor.xcstrings` catalogs use Interface Builder's required `objectID.property` keys. Objects containing localizable text have readable IDs and user labels. Preserve those IDs after translation begins and keep connections intact when adding scenes.

`InfoPlist.xcstrings` uses Apple's metadata keys and document-type names as lookup keys. These keys are exceptions to the semantic code-key convention. Brand names and shortcut glyphs are not ordinary translatable prose.

## Refresh and verify

Run `python3 scripts/update-localizations.py --write` after changing source text or storyboard labels. This extracts Objective-C with `genstrings` and Interface Builder text with `ibtool`, preserves translations, marks changed translations for review, and retains removed entries as stale for explicit review. Private dylib sources are included in their enclosing framework's catalog. Run without `--write` to check that extracted keys and English values match; remove reviewed stale entries explicitly.

Composer’s Base storyboard and `mul.lproj/Main.xcstrings` catalog participate in the same extraction check.

Run `scripts/check-build.sh` to validate compilation and framework products; installed resource and dependency resolution still require a runtime check. Before shipping translations, verify the built apps: menus, editor scenes, toolbar tooltips, accessibility labels, undo/redo names, errors, and Help. Test long text, right-to-left layout, mixed Arabic/Latin content, and missing-translation fallback separately. Do not translate authored Work content when the UI language changes.

## Validation of this foundation

On 2026-09-12, a clean full build of the Folio scheme succeeded with no compiler warnings or errors. The post-build extraction check matched 36 Objective-C strings and 284 storyboard strings; the two app metadata catalogs contain another six entries. All original storyboard text, scene structure, and connections were checked against the previous versions after accounting for renamed object IDs. Both apps retained their framework and private-library embedding.

A temporary AppKit host exercised the built frameworks in English and with deliberately incomplete French marker resources in disposable build products. It verified framework-owned default titles and error descriptions, editor loading from the Base storyboard, localized tooltips and accessibility labels, English fallback for a missing translation, Manuscript outlet connections, and Work save/reopen. An English title saved in one process remained English when reopened in the French process. Those marker strings were test fixtures only, not source translations.

This validates resource routing and the English baseline. Full native UI regression, translated layout quality, and right-to-left editing remain separate checks before shipping translated interfaces.
