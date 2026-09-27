<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Native paragraph baseline — 27 September 2026

## Result

Native TextKit 2 is worth retaining for the next comparison. In the inspected
Latin Modern samples, it produces more even texture than the Core Text
framesetter baseline. The narrow Latin paragraph still has conspicuously loose
lines. These observations support a focused Latin hyphenation/break-selection
experiment; they do not yet establish the required quality threshold.

The run produced **144 complete cases**: four source paragraphs × three fonts ×
three measures × two requested hyphenation settings × two engines. Core Text's
hyphenation setting is a labeled duplicate baseline because this experiment
does not control it. All cases cover the full input without gaps or overlaps.

## Environment and controls

- Apple Silicon, macOS 27.0 (26A428), Xcode 27.0 (27A266a), SDK 27.0.
- 12 pt; widths 240, 300 and 360 pt; justified text; native default font features,
  kerning and line spacing; raster images at 2×. TextKit 2 uses zero container padding.
- Times-Roman 22.0d2e1; LMRoman12-Regular internal version 2.004 from Latin Modern
  package 2.005; CMUSerif-Roman 0.7.0. These are distinct faces.
- TextKit 2 explicitly sets `usesHyphenation`, `hyphenationFactor`, and
  `usesDefaultHyphenation = NO`. Both paths set the language attribute.
- Core Foundation reports hyphenation available for `en` and unavailable for
  `la` on this host. That availability query does not prove TextKit's private
  implementation uses that same dictionary.

## Observations

1. For each font, TextKit 2's hyphenation toggle changed the break sequence in
   **6/6 English cases and 0/6 Latin cases**. English visibly gains hyphens.
   Latin language-correct hyphenation is the immediate uncertainty to resolve.
2. The Latin Modern Latin article 1 at 240 pt shows conspicuous letter spacing
   within words in the Core Text baseline. TextKit 2 keeps a more consistent
   texture, though lines such as “ordinatur ad Deum sicut ad quendam” remain loose.
3. The Latin Modern English article 1 at 300 pt with TextKit 2 hyphenation enabled
   is a useful favorable sample. The Core Text comparison leaves an isolated
   “revelation.” on its final line and has visibly uneven spacing earlier.
4. Core Text reported no fallback font runs in any specimen. TextKit 2 resolves
   the requested base font, but its line-fragment interface does not expose
   actual fallback runs; this experiment cannot claim equivalent fallback proof.

The four representative PNGs in [evidence](evidence) were inspected directly.
All line ranges, geometry and space-advance diagnostics are retained in the
three compact JSON records there. PNG filenames in those records refer to the
generated per-font output directories; only the four discussed PNGs are committed.
`evidence/run.json` pins inputs and environment. The larger interactive
`build/results/comparison.html` is generated locally and includes all 144 PNGs.
Its browser interactions have not been verified: the browser tool blocks local
file URLs. The native PNGs and JSON were verified independently.

## Recommended next experiment

Keep the same fixtures and native shaping. First provide known, editorially
checked Latin hyphenation opportunities and compare their effect at the three
measures. Then test a small paragraph-wide break search against this baseline
if loose lines remain. Judge changes in complete paragraphs, preserving the
input provenance and explicit limits on spacing and consecutive hyphens.

Human approval of the typography threshold is pending. This prototype establishes
a repeatable baseline; it does not decide the production engine, prove a global
optimum, or validate page/Stream coordination or native editing integration.

## Validation

The harness compiles with `-Wall -Wextra` without diagnostics. The agreed CLI
checks pass: 4 tests, 396 assertions, including complete Unicode coverage and
repeatable breaks. Empty fixture lists and duplicate/empty identifiers were
first demonstrated failing and then fixed. Rendering coverage/repeatability
checks were added against the working renderer and are characterization checks,
not a claim that the renderer was built test-first.
