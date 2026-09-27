<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Core Text caller controls

This standalone probe answers the control question for issue #22 and ADR 0012. It uses Times-Roman at 12 pt on a simple left-to-right Latin-script fixture. Run both probes from the repository root with:

```sh
ruby Composer/Prototypes/ParagraphComposition/Controls/run.rb
```

The Core Text program writes `results.json` and eight PNGs beneath `build/coretext/`. The saved [`coretext-results.json`](coretext-results.json) is the measured run captured for review. Results include OS, SDK, Times-Roman version, every request, actual line metrics, pass/fail limits, and PNG names. `build/` is disposable.

## What the run establishes

| Control | Observed result | Boundary |
| --- | --- | --- |
| Explicit breaks | `CTTypesetterCreateLine` returned the exact requested UTF-16 ranges `[0,5]` and `[5,8]` for `extraordinary`, with complete source coverage. | Folio supplied the approved break at index 5. Core Text did not choose it. |
| Break validation | A break at unapproved index 3 and a break inside `a` plus combining acute at index 1 were rejected before calling the typesetter. | The caller owns the allowlist and grapheme check. |
| Discretionary hyphen | Derived rendered lines `extra-` and `ordinary` were shaped with Core Text. The 13-unit logical source remains `extraordinary`; the output maps the inserted hyphen to no source range. | This is one prebreak substitution example, not general hyphenation or source mapping for editing and accessibility. |
| Overfull request | An exact eight-`M` line advanced past a 20 pt measure. The output reports the overflow and preserves the full requested range. | The caller must detect and score infeasible lines; Core Text did not silently rebreak it. |
| Tracking | `kCTTrackingAttributeName` 0 to 0.5 pt moved the fourth `H` glyph origin by 1.5 pt. The caret offset at UTF-16 index 3 moved by 1.25 pt; those are distinct Core Text measurements. | This proves fixed tracking control for this font/string, not paragraph optimization. |
| Built-in hanging punctuation | `kCTParagraphStyleSpecifierLineBoundsOptions` with `kCTLineBoundsUseHangingPunctuation` shifted the opening-quote ink edge left by the quote advance, about 5.326 pt, while the frame origin remained at x=0. | The option has no caller-selected 0/50/100 percentage. |
| Caller quote protrusion | A constructed drawing shows origins at 0, about -2.663, and about -5.326 pt for 0/50/100 percent of quote advance. Status is `demonstrated` because the metric equation is set by the probe itself. | This whole-line offset also moves the interior text. A fixed interior anchor needs more caller layout work. |
| Quote-only glyph positioning | After shaping the full `“Quoted words”` line, the probe extracts Core Text glyph IDs, positions, UTF-16 string indices, and run font. It shifts only the opening quote glyph by 0, 50, or 100 percent of its 5.326 pt advance and draws the extracted run glyphs. A separate 4× raster check measured opening-quote left-edge shifts of 0, -2.75, and -5.5 pt; interior ink bounds stayed exactly 5.5–77.75 pt. The shifts are within 0.35 pt of the requested 0, -2.663, and -5.326 pt, accounting for raster quantization. | This is Folio-owned glyph positioning for one simple line. Hit testing, selection, copy, accessibility, and arbitrary-script behavior are not implemented. |
| Bounded expansion | Separate CTFont matrix variants at 0.98, 1.00, and 1.02 yielded measured line advances about 58.140, 59.326, and 60.513 pt, matching the requested horizontal scales within 0.05 pt. | This is a primitive for the fixture, not a typographic quality or general-script proof. |

The complete run has eight `pass` cases and one `demonstrated` case, with no failures. The output images show margin and measure guides. `hanging-built-in.png` shows the native opening quote shift; `quote-only-glyph-positioning.png` shows the caller's quote-only shift while the remaining text stays aligned.

## Policy conclusion

Core Text exposes lower-level controls for a Folio-owned paragraph compositor: construct intact shaped lines from approved source ranges, include a selected discretionary glyph in a derived line, apply fixed tracking, use its hanging-punctuation option, position extracted glyphs, and apply a bounded font matrix. Folio must still compute allowable breaks, handle mandatory breaks and substitutions, measure alternatives, penalize overfull or loose lines, choose a paragraph-wide sequence, preserve logical-to-rendered mapping, and coordinate layout with page and Stream constraints. This run makes no claim that Core Text has supplied that optimizer.

The fixtures do not establish behavior for mathematics, bidirectional text, complex scripts, or arbitrary composed sequences across a discretionary break. The probe validates a composed-cluster boundary before splitting, and Core Text shapes each intact line. More language and content-specific experiments are needed before admitting the primitives into publication policy.
