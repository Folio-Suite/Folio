<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# TypographyKit

TypographyKit is an independent Swift framework for controlled text composition
above Core Text. It depends on Foundation, Core Text, and Core Graphics. ComposerKit
owns publication meaning and supplies neutral, immutable inputs.

`TypographyComposer.compose(_:)` is synchronous. A caller supplies one or more
source occurrences, a PostScript font name, language/script/direction, line width
and height, exact selected UTF-16 break offsets, required and forbidden break
constraints, optional discretionary replacements, and numeric adjustments. The
final break must equal the total source length. The operation does not choose
breaks. A new request can reconsider the paragraph under new constraints.

The result retains the original Unicode text without normalization, exact
rendered lines, occurrence-aware source mappings, glyph positions, separate caret
positions, ink bounds, actual font names and font version, OS provenance,
structured diagnostic codes, and a status of `complete`, `unsupported`, or
`infeasible`. Drawing uses native glyph resources retained by that same result.
An overfull line is returned with `infeasible` status so the caller can inspect
its actual geometry; rejected inputs return no lines. Hosts should translate
structured diagnostic codes into their own localized wording.

## Supported subset

- Left-to-right Latin text with a resolved PostScript font. Fallback can be
  allowed explicitly; otherwise a fallback makes the result infeasible.
- Caller-selected legal grapheme and shaping-cluster boundaries. No opportunity
  generation or hyphenation dictionary is included.
- Discretionary before-break, after-break, and no-break material, including
  inserted, omitted, and substituted source mapping.
- Fixed tracking, positive added interior ASCII-space width, bounded horizontal
  font-matrix expansion, and bounded protrusion of an opening quotation glyph.
  Protrusion moves only that glyph; caret offsets retain their logical positions.

Complex scripts, bidirectional text, mathematical layout, paragraph optimization,
negative space adjustment, arbitrary punctuation rules, native selection and
accessibility hosting, and publication output remain separate work. The explicit
subset and result status prevent a preview from claiming those capabilities.
The checked-in Core Text and TextKit 2 specimens under
`Composer/Prototypes/ParagraphComposition/` remain comparison evidence.

## Validation

Build the standalone framework:

```sh
xcodebuild -project TypographyKit/TypographyKit.xcodeproj -scheme TypographyKit \
  -destination 'platform=macOS' -derivedDataPath /tmp/typography-build build
```

Run the public behavioral cases against its product:

```sh
TypographyKit/Tests/run.sh /tmp/typography-build/Build/Products/Debug
```

The shared `TypographyKit` scheme also runs the `TypographyKitTests` XCTest
target with `xcodebuild test`. The behavior runner above compiles a separate
Swift client against the built framework. The Suite's
`scripts/check-kit-interfaces.rb` also compiles and links the isolated
Swift consumer on arm64 and x86_64. The framework targets macOS 14, Swift 6 with
nonisolated core code, and the Suite's coordinated version and signing settings.
These checks establish the stated subset; human page-quality review and native
interaction acceptance remain separate.
