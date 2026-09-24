<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Localization

Plain American English is the development language. Use American spelling and
clear, direct wording; avoid regional idioms, slang, and culturally specific
shorthand. Catalogs retain the `en` source identifier rather than introducing a
separate `en-US` resource hierarchy. This choice does not set the language or
regional conventions of an authored Work.

The Suite includes initial translations for Spanish, French, German, Japanese,
Simplified Chinese, Brazilian Portuguese, Traditional Chinese, Korean, Italian,
and Arabic. These translations are a courtesy to users, not a claim of perfect
local fidelity or completed human review. All initial target-language entries
are marked `needs_review`. Xcode 27 compiles that state into usable language
resources; the flag does not prevent display. Reviewers may mark entries
`translated` after reviewing them in context.

## Code strings

Use `NSLocalizedStringWithDefaultValue` with a stable, descriptive key, literal English fallback, and a translator comment. Name the intent, such as `work-package.read.error` or `manuscript.rename-content-unit.undo`, rather than using the English sentence as the key. Separate meanings even when their English spelling matches. Give AppKit the action name for undo; do not construct an English “Undo …” sentence.

Resolve strings from the owning framework's bundle (`dev.foliosuite.FolioKit`, `dev.foliosuite.WriteKit`, `dev.foliosuite.ResearchKit`, or `dev.foliosuite.ComposerKit`). Implementation subfolders share that framework’s catalog; do not assume the application’s main bundle. Application-owned strings use their app bundle. XPC services own their strings separately; add their catalog resource when the first user-facing service message is introduced.

Keep filenames, model attributes, format identifiers, action selectors, and accessibility identifiers stable and untranslated. Localize accessible labels and help. A new Content Unit gets its default title in the current language at creation; subsequently that title is authored data and must survive language changes unchanged.

For new count-bearing messages, use catalog plural variations and localized formatting. Keep full sentences together with reorderable placeholders, and explain each placeholder to translators. Do not concatenate translated fragments.

Accessibility labels and undo action names have separate keys even when English
uses the same wording: other languages may require different grammatical forms.
Likewise, distinguish the Write application name from the verb, Research from an
activity, and Composer from a person's role. Use the approved application names
below; translate the descriptive words in document type names. `CONTEXT.md` defines domain meaning;
translators should use a consistent reviewed term for each concept, not assume
English capitalization or a literal word-for-word rendering carries that meaning.
Keep Emphasis/Strong Emphasis distinct from visual Italic/Bold in every context.

UI language, locale, paragraph direction, and authored language are independent.
Natural paragraph alignment follows text direction; it must not become a synonym
for left alignment. Do not infer a Work's language from the application's locale.
Preserve Unicode text and authored titles through editing, undo, and persistence.

## Interface Builder and metadata

Menus remain in each application's `Base.lproj/Main.storyboard`. The editor's scenes remain in WriteKit's `Resources/Base.lproj/Editor.storyboard`. Their `mul.lproj/Main.xcstrings` and `mul.lproj/Editor.xcstrings` catalogs use Interface Builder's required `objectID.property` keys. Objects containing localizable text have readable IDs and user labels. Preserve those IDs after translation begins and keep connections intact when adding scenes.

`InfoPlist.xcstrings` uses Apple's metadata keys and document-type names as lookup keys. These keys are exceptions to the semantic code-key convention. Brand names and shortcut glyphs are not ordinary translatable prose.

## Application names

Localize names case by case when doing so makes their purpose clearer. For this
pass, keep **Folio** unchanged in every language; Japanese and European-language
interfaces also retain **Write**, **Research**, and **Composer**. Chinese, Korean,
and Arabic use the following names in menus, help, errors, and bundle display
metadata. Composer refers to page composition and publishing, not music.

| Language | Write | Research | Composer |
| --- | --- | --- | --- |
| Simplified Chinese | 写作 | 研究 | 排版 |
| Traditional Chinese | 寫作 | 研究 | 排版 |
| Korean | 글쓰기 | 자료 조사 | 조판 |
| Arabic | الكتابة | البحث | الإخراج |

These are initial localized names under the approved per-language policy, and
remain subject to review like other translations. Future translations of Folio
itself require a case-by-case decision. Bundle identifiers, executable names,
framework names such as WriteKit, file extensions, and resource filenames remain
unchanged. `CFBundleName` and `CFBundleDisplayName` are localizable and must not
be globally marked “do not translate.” Visible shortcut glyphs remain protected.

## Refresh and verify

Run `ruby scripts/update-localizations.rb --write` after changing source text or storyboard labels. This extracts Objective-C with `genstrings` and Interface Builder text with `ibtool`, preserves translations, marks changed translations for review, and retains removed entries as stale for explicit review. Framework implementation subfolders are included in their owning framework’s catalog. Run without `--write` to check that extracted keys and English values match; remove reviewed stale entries explicitly.

Extraction includes `.h`, `.m`, and `.mm` files in applications, Kits, and XPC
services. Verification also checks extracted translator comments. Structured
English plural/device/substitution entries require manual review: the script
refuses to flatten them into a plain fallback. Changes to plain English sources
mark nested translation variants for review too. This is a preservation guard,
not an automated plural authoring workflow. Validate metadata catalogs separately
against Info.plist and generated bundle settings.

Never mark copied English prose as a completed translation. Brand names and
shortcut glyphs can intentionally stay identical; prose needs language review.
Do not discard existing translation text merely because its status is suspect.

Composer’s Base storyboard and `mul.lproj/Main.xcstrings` catalog participate in the same extraction check.

Run `scripts/check-build.sh` to validate compilation and framework products; installed resource and dependency resolution still require a runtime check. Before shipping translations, verify the built apps: menus, editor scenes, toolbar tooltips, accessibility labels, undo/redo names, errors, and Help. Test long text, right-to-left layout, mixed Arabic/Latin content, and missing-translation fallback separately. Do not translate authored Work content when the UI language changes.

## Validation of this foundation

On 2026-09-12, a clean full build of the Folio scheme succeeded with no compiler warnings or errors. The post-build extraction check matched 36 Objective-C strings and 284 storyboard strings; the two app metadata catalogs contain another six entries. All original storyboard text, scene structure, and connections were checked against the previous versions after accounting for renamed object IDs. Both apps retained their framework and private-library embedding.

A temporary AppKit host exercised the built frameworks in English and with deliberately incomplete French marker resources in disposable build products. It verified framework-owned default titles and error descriptions, editor loading from the Base storyboard, localized tooltips and accessibility labels, English fallback for a missing translation, Manuscript outlet connections, and Work save/reopen. An English title saved in one process remained English when reopened in the French process. Those marker strings were test fixtures only, not source translations.

This validates resource routing and the English baseline. Full native UI regression, translated layout quality, and right-to-left editing remain separate checks before shipping translated interfaces.

See the [September 2026 localization audit](localization-audit-2026-09.md) for the
current inventory, repaired safeguards, and remaining preparation checks.
