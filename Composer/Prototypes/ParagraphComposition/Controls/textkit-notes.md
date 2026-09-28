<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# TextKit 2 control probe

Run `xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework AppKit -framework CoreText textkit.m -o textkit` from this directory, then `./textkit --output build/textkit`. The program writes `results.json`; `textkit-results.json` is the compact, checked-in result from the same run. All 17 cases have complete UTF-16 range coverage. The source text uses synthetic discretionary soft hyphens and an English language attribute. The requested font is Times-Roman at 12 points. See the JSON for OS, SDK, font version, and preferred languages.

## Break control

- At 100 points, each plain `extraordinary` fits. With `usesHyphenation = NO` and paragraph `hyphenationFactor = 0`, the three words break only at offsets 14 and 28. The delegate gets no `hyphenating = YES` calls. At 58 points, the same disabled setting still produces emergency intraword breaks at 11, 25, and 39. Disabling automatic hyphenation is therefore distinct from forbidding all intraword breaks.
- Explicit soft hyphens produce candidate callbacks even with automatic hyphenation disabled. With all six soft-hyphen offsets allowed at 58 points, the observed breaks are 10 and 20. This is a synthetic line-break control test, not a claim about linguistic syllabification.
- A feasible prescribed alternative works: for `Today ex\u00adtra\u00ador\u00addinary` at 80 points, the native baseline breaks at 17. A delegate allowing only offset 9 makes the break at 9, with line widths 48.14 and 53.31 points, both within the measure. Other candidate callbacks are rejected. This proves the delegate can select a feasible earlier break from native candidates.
- At 58 points, a policy allowing only offset 3 across two long words cannot fit the remainder without another break. The delegate selects 3 but layout also breaks at the natural word boundary 17 and the emergency intraword point 31, despite veto callbacks. With every candidate vetoed, it makes emergency intraword breaks at 14 and 29. The failures show that a veto is not a hard global break constraint under adversarial width. A Composer wrapper needs to detect a policy violation and reject or recompose; it cannot assume `NO` guarantees an unbroken range. The experiment does not show what TextKit 2 does for every feasible requested sequence.

## Tracking and expansion

`NSTrackingAttributeName = 0.5` on `HHHH` increases the line width from 34.6641 to 36.6641 points. Caret offset 3 changes by 1.25 points, and final offset 4 changes by 1.5 points; caret positions are not individual glyph ink origins. This is evidence of fixed tracking, not a per-line optimization rule.

An `NSFont` horizontal text transform of 0.98 or 1.02 changes the measured `HHHH` width by those ratios. A fixed font transform is thus a native way to apply a predetermined expansion or compression. The selected SDK marks `NSExpansionAttributeName` unsupported with TextKit 2. This probe does not exercise automatic per-line glyph expansion or optimization across tracking, expansion, and break choices.

## Punctuation

A 10-point first-line indent places the opening quotation mark at x = 10. For the two variants, the indent is reduced by 0.5 or 1 point and the same amount of `NSKernAttributeName` is applied to the opening quote. The raster at 8 pixels per point shows both quote ink runs moving left by exactly 0.5 or 1 point while every following ink-column run remains at its baseline x coordinates. The following caret moves left by only 0.25 or 0.5 point, so caret geometry alone would have given the wrong answer about the rendered glyphs. This construction supports a specified amount of **initial-quote protrusion on the first line** without character substitution or custom drawing.

The original run applied `NSTrackingAttributeName = 0` to every character. The selected SDK's `CTStringAttributes.h` states that when both kern and tracking keys are present, nonzero kern is ignored. The corrected punctuation cases omit tracking entirely, and the JSON records whether each attribute is present. Other attribute combinations were not exhaustively tested. A documented TextKit 2 paragraph interface for an arbitrary punctuation protrusion table across all line edges was not found in the selected AppKit headers. Native justification at 75 points was separately measured and should not be mistaken for such an interface.

The result JSON records per-case requests, expected contracts, actual break offsets, candidate callbacks with UTF-16 positions and hyphenating flags, line geometry, and pass/fail. Its failures are capability boundaries of these tested controls, not a claim that all native-assisted composition strategies fail.
