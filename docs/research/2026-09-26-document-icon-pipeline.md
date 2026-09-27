<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# macOS document icons: asset catalogs, composition, and complete artwork

Research date: **26 September 2026**. Scope: Folio's Work, Source Library, and Edition file icons on macOS Sonoma 14 and the current Xcode/macOS 27 toolchain. This is a research recommendation, not a migration decision or Finder verification.

## Implementation follow-up — 26 September 2026

The recommendation below was subsequently exercised. Folio now uses transparent
PNG badge icon sets in each app’s asset catalog, selected by `UTTypeIcons`, with
separate ZIP badges at larger sizes. Complete custom ICNS trials and duplicate
app-icon design packages were removed. See the current [badge sources and generation](../../Design/Icons/Documents/README.md)
and [file-type registrations](../document-file-types.md).

A disposable file type using Composer’s compiled catalog rendered its badge and
label through `NSWorkspace`. Existing Composer registrations still returned a
blank page; one selected an older packaged build under `dist`. That experiment
confirmed the composition path works and exposed development registration/cache
interference. It did not verify all final types, languages, sizes, or Sonoma.
At that point, Finder rendering and localized icon-text resolution remained
runtime checks. After PR #25, the user confirmed on 26 September 2026 that newly
created documents showed the icons correctly on the current machine. This is
current-machine Finder smoke evidence, not coverage of every size, language, or
Sonoma. See the [recorded verification](../../Design/Icons/Documents/README.md).

## Original recommendation

**Keep Icon Composer for app icons. For document icons, prototype Apple's asset-catalog-backed, system-composed document pipeline before deciding to retain the complete ICNS designs.** The user's expectation about asset catalogs is well founded. The existing ICNS approach is documented, but it gives Folio responsibility for the complete page rendering. It is an artistic-control option, not the only native document-icon workflow. This recommendation follows the distinct documented app-icon, document-composition, and complete-file routes below. [Icon Composer][composer]; [UTTypeIcons][icons]; [complete document icons][cfkeys]

Use a folded page for all three document types, with the agreed amber nib, violet book, and cobalt layout identity. The requested Library silhouette change is an artwork decision independent of the storage package format. Prefer a restrained native page with deliberately designed artwork over automatically shrinking the entire app tile into its center. Apple describes the folded corner as a document-recognition cue and explicitly supports custom background artwork as well as badges. [HIG, macOS document icons][hig]

## What Apple documents

| Route | Authoring and registration | What controls the appearance |
| --- | --- | --- |
| Layered app icon | Modern Icon Composer `.icon`, configured as the target's app icon | Icon Composer layers and system app-icon treatment. Apple's instructions are specifically about app icons; they do not establish `.icon` as a document-type resource. [Icon Composer][composer] |
| Templated document icon | Named asset-catalog icon sets referenced by `UTTypeIcons` in the exported type declaration | The app provides background, badge, and/or label; the system scales, masks, and composites them onto its folded page. [UTTypeIcons][icons] |
| Complete custom document icon | Bundled multiresolution `.icns`, referenced by `CFBundleTypeIconFile`; exported type declarations also have `UTTypeIconFile` | The file supplies the complete artwork rather than separate template ingredients. These remain documented keys. [Core Foundation keys][cfkeys]; [UTI declaration][uti] |

The current Icon Composer documentation says that a supplied `.icon` replaces an existing **app-icon** asset catalog. That rule is not evidence that document icon sets must also move to Icon Composer. Also beware archived documentation mentioning “Icon Composer”: the old ICNS-authoring tool shared the name with today's layered app-icon application. Do not apply the archived tool instruction to the modern `.icon` format. [Icon Composer][composer]; [archived document icon instructions][cfkeys]

## The asset-catalog route

`UTTypeIcons` has the document fields `UTTypeIconBackgroundName`, `UTTypeIconBadgeName`, and `UTTypeIconText`. Background and badge reference named icon sets; the text is a short label. Omitting fields invokes defaults: app icon for badge, filename extension for text, and no custom background fill. Simply omitting the badge field therefore does **not** promise a badge-free result. [UTTypeIcons][icons]; [badge field][badge]

Apple explicitly documents an asset-catalog **`.iconset`** type, distinct from `.appiconset` and `.imageset`. Its files use names such as `icon_16x16.png` and `icon_16x16@2x.png`; the documented full set has 16, 32, 128, 256, and 512 point slots at 1x and 2x. The format reference says `.iconset` has no `Contents.json`. These are catalog source assets, whereas `.icns` is a compiled multiresolution resource. The format reference is archived, so compilation with the installed Xcode remains part of any implementation check. [Icon Set Type][iconset]; [asset types][asset-types]

The system badge occupies half the document canvas, and Apple recommends keeping most badge artwork within roughly 80% of that smaller canvas. This helps explain why inserting a complete app tile can look undersized. Apple also describes richer **background-only** examples. For more prominent Folio symbols, compose the symbol into a custom background fill and let the system supply the page silhouette, fold, and label. Verify how the current Xcode fields suppress the default badge before shipping this variant; the inspected references do not specify a portable empty-string suppression contract. [HIG][hig]; [badge field][badge]

Apple advises simple shapes, a limited palette, and simpler small-size variants because documents can appear at 16 pixels. Keep important background details away from the upper-right fold. Thus the existing separately simplified small artwork is still useful if moved into catalog icon sets. [HIG][hig]

## Compatibility and evidence limits

- **Sonoma is not an obstacle to templated document icons.** Apple's current documentation metadata marks `UTTypeIcons` and `UTTypeIconBadgeName` as introduced in macOS 11. Xcode 12's release notes independently announce support for those macOS 11 templated document icons in the document/type editors. This is availability evidence, not a Folio runtime test. [UTTypeIcons][icons]; [badge field][badge]; [Xcode 12 release notes][xcode12]
- **Complete ICNS is not shown as obsolete by these sources.** Apple still publishes `CFBundleTypeIconFile` and `UTTypeIconFile`. A 2024 Apple DTS response explicitly recommends a complete `.icns` for document icons, although its immediate question concerns Mac Catalyst. That answer also mentions `UTTypeIcons/UTTypeIconName`, which the current public dictionary reference does not list. Do not adopt that extra key as Folio's primary route without further validation. [CFBundleTypeIconFile][type-file]; [UTI declaration][uti]; [DTS discussion][dts]
- **No inspected primary source establishes modern `.icon` document-type registration or an OS-27 requirement to use it.** The current app-icon guidance alone does not establish such support. This is a limit of the evidence, not a claim that every conceivable use is impossible. [Icon Composer][composer]
- **Runtime precedence is not proved.** The inspected sources do not provide a complete ordering when `CFBundleTypeIconFile`, `UTTypeIconFile`, and templated `UTTypeIcons` coexist. Avoid calling one a reliable fallback for another without testing both OS versions. Apple DTS cautions that Launch Services can select another installed copy of an app, making development-machine icon results misleading. [DTS discussion][dts]

## Bounded next experiment

Keep the accepted app icons unchanged. In an isolated document-icon trial, compile catalog icon sets for one type, register the template fields, and compare a center-badge variant with a full-background-art variant. Use a distinct test bundle/type identity or a clean VM so another Folio build cannot win registration. Check Finder list and icon views and a Save/Open panel on Sonoma and the current OS, including small sizes. Record whether the fold, scale, label, and badge behave as intended before migrating the remaining types. These are proposed verification steps, informed by Apple's registration caveats; no such experiment was executed in this research pass. [DTS discussion][dts]

If template composition still constrains the accepted design too much, retain the complete ICNS route deliberately. A successful resource build proves packaging, not Finder rendering.

## Sources

[hig]: https://developer.apple.com/design/human-interface-guidelines/icons#macOS
[icons]: https://developer.apple.com/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons
[badge]: https://developer.apple.com/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons/uttypeiconbadgename
[composer]: https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer
[cfkeys]: https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
[type-file]: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledocumenttypes/cfbundletypeiconfile
[uti]: https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/understanding_utis/understand_utis_declare/understand_utis_declare.html
[iconset]: https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/IconSetType.html
[asset-types]: https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AssetTypes.html
[xcode12]: https://developer.apple.com/documentation/xcode-release-notes/xcode-12-release-notes
[dts]: https://developer.apple.com/forums/thread/761775

Apple's public DocC JSON representations were also read to retrieve the JavaScript-rendered HIG text and platform availability metadata: [HIG JSON](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/icons.json), [UTTypeIcons JSON](https://developer.apple.com/tutorials/data/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons.json), and [badge JSON](https://developer.apple.com/tutorials/data/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons/uttypeiconbadgename.json).

## Background-property follow-up — 26 September 2026

**Yes: `UTTypeIconBackgroundName` preserves the system's folded-page composition.**
It names an icon set in the app's asset catalog, used as the document's background
fill. The system scales that artwork to the document canvas, clips it to the
folded-page silhouette, and draws the fold over its upper-right area. The HIG
specifically describes a white fold over the fill. Background artwork therefore
does not require drawing a replacement page or fold; keep important content away
from that corner. [Background property][background]; [HIG][hig]

The background can coexist with the badge and text. Omitting the background gives
no custom fill; omitting the badge instead selects the app icon, and omitting text
selects the extension. The HIG shows background-only designs, but these references
do not document an empty-string contract for suppressing the default badge.
[UTTypeIcons][icons]; [HIG][hig]

The property's current DocC metadata marks macOS availability from 11.0. These
are documented composition semantics, verified against Apple's public JSON on
this date, not a Folio background-variant runtime test. No background assets or
registrations were changed during this follow-up; the user's Finder smoke result
above covers the existing badge configuration.
[Background JSON][background-json]

[background]: https://developer.apple.com/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons/uttypeiconbackgroundname
[background-json]: https://developer.apple.com/tutorials/data/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons/uttypeiconbackgroundname.json
