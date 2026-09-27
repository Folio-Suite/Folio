<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Document badges

The app catalogs contain `WorkIcon.iconset`, `LibraryIcon.iconset`, and
`EditionIcon.iconset`. Each has ten transparent PNG representations: 16, 32,
128, 256, and 512 points at 1x and 2x. They depict only the nib, book, and layout
symbols. `UTTypeIcons/UTTypeIconBadgeName` references the matching set; macOS
provides the document page and fold. `UTTypeIconText` supplies the short Document
or Archive label; corresponding entries in each `InfoPlist.xcstrings`
provide initial translations for the supported languages. macOS uppercases and
scales icon text. Compiled translations still require Finder verification,
including whether this nested metadata field resolves the localized value. Complete
custom ICNS registrations have been removed to avoid competing icon routes.

`<Type>-Badge-Large.svg` includes fine detail, `-Medium.svg` removes engraving and
page text, and `-Tiny.svg` additionally removes outlines. Select detail by logical
size, not pixel count: a 32-point Retina icon still needs the tiny artwork.
Explicit size-named SVG sources override the general detail levels where
optical corrections are needed. Composer uses a transparent overlap gap at 16 and 32 points, no insets at
16 points, and one inset color at 32 points. The overlap gap
continues at 128, 256, and 512 points, progressively finer relative to the symbol. Write has a wider
slit at 16 points. These choices also apply to their Retina representations.
Regenerate the catalogs after editing these sources:

```sh
ruby scripts/render-document-icons.rb
```

The Ruby script uses the native AppKit SVG renderer in `render.swift`. SVG is
editable source, not an iconset input. Xcode 27 accepts SVG in ordinary image sets
but omitted SVG from an iconset in a controlled compilation probe; PNG compiled
in the same set. Apple's documented iconset format specifies PNG filenames.

A disposable Composer type confirmed system composition of its compiled badge.
After PR #25 merged, the user confirmed that new documents worked and their
Finder icons appeared correctly on the development machine (26 September 2026).
This smoke check does not establish all sizes, localized icon text, Save/Open
panel rendering, or Sonoma behavior; Quick Look thumbnails and cached
registrations can affect what is shown.

## Appearance and accent colors

Each app's `AccentColor` supplies Any/Light and Dark colors in its amber, violet,
or blue family. Existing app target settings select that named global accent.
System controls can still respect the user's macOS accent preference.

The document `.iconset` format has named size/scale slots and no documented
appearance variants. One palette is supplied for both appearances. This differs
from color sets and ordinary image sets; their appearance support does not prove
Finder will select dark document-badge artwork. No undocumented naming convention
or alternate registration has been added.

See [document-icon research](../../../docs/research/2026-09-26-document-icon-pipeline.md),
[Apple's composition keys](https://developer.apple.com/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons),
and [iconset format](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/IconSetType.html).

## Symbol representation

`UTTypeSymbolName` names an SF Symbol for each type: `doc.text` for Works,
`books.vertical` for Libraries, and `rectangle.split.2x2` for Editions. These
provide a system-symbol representation separate from the custom icon badge.
The key is not an accessibility-description field; localized document-type
descriptions remain separate. The selected names were resolved with AppKit
on the development OS; minimum-OS rendering remains part of runtime checks.

## ZIP variants

`WorkZipIcon`, `LibraryZipIcon`, and `EditionZipIcon` are separate catalog sets
registered for the ZIP types. At 16 and 32 points their PNGs are identical to
the native badges, including Retina. At 128 points and larger, the generator
adds the shared `Zip-detail.svg` zipper. This indicates ZIP packaging, not
archival-folio completeness. Size is the selection criterion; Finder can use
these representations in more than one view mode.
