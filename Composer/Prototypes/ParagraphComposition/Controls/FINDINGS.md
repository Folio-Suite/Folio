<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Composition control findings

27 September 2026 · issue #22 · macOS 27.0 (26A428) · Xcode 27.0 (27A266a)

## Recommendation

**Build a Folio-owned publication compositor above Core Text.** The expanded
requirements call for Folio to choose complete break sequences, enforce spacing
and expansion budgets, apply punctuation rules, and report infeasible layouts.
Core Text supplies construction and measurement APIs that fit that ownership.
Folio must supply the composition algorithm and prove the resulting quality.

This is a recommendation from the experiments and inspected public interfaces,
not an adopted architecture decision. The experiments are outside production
targets. TextKit 2 remains a useful quality baseline and a candidate for editing
or hosting composed output; that integration has its own untested contracts.

## The three questions

| Requirement | TextKit 2 native composition | Folio composition using Core Text |
| --- | --- | --- |
| Correctly control hyphenation | Supplied soft hyphens work with automatic hyphenation disabled. The delegate successfully selects an earlier feasible candidate. Under infeasible constraints, layout still inserts breaks after vetoes. | Folio chooses an approved boundary and shapes the chosen ranges. The probe inserts the selected visible hyphen into derived output while preserving logical source. Folio owns linguistic correctness and source mapping. |
| Control breaking, tracking, and expansion | Fixed tracking and 0.98/1.02 font transforms change measured geometry. A native candidate can be vetoed, but the inspected API does not expose paragraph costs or an arbitrary complete sequence constructor. | Explicit line ranges are retained, including a requested overfull line. Fixed tracking moves measured glyph origins; font transforms change measured advances. Folio can measure and compare alternatives before selecting a sequence. |
| Control hanging punctuation and other microtypographic primitives | First-line indent plus quote kerning moves only the opening quote's ink by 0.5/1 pt in the tested line. No arbitrary protrusion-table interface was found in the inspected public API. This does not exhaust custom fragment or drawing approaches. | The native hanging-punctuation option moves the opening quote's ink edge beyond the margin. A separate caller-positioning test moves only that quote, with raster measurements confirming unchanged interior bounds. |

The second column describes native TextKit 2 composition. The third includes
application-owned decisions. Drawing Folio's Core Text lines inside a TextKit 2
fragment would retain that application ownership.

### 1. Hyphenation: candidates, selection, and failure

At an 80 pt measure, TextKit 2 ordinarily breaks
`Today ex\u00adtra\u00ador\u00addinary` at UTF-16 offset 17. Allowing only the
candidate at offset 9 produces that break, and both resulting lines fit:
48.14 and 53.31 pt. **Its delegate is effective control for this feasible case.**

At a 58 pt measure, permitting only offset 3 across two long words cannot yield
a fitting composition. TextKit 2 uses offset 3 and also breaks at 17 and 31;
vetoing everything yields breaks at 14 and 29. These cases distinguish a break
veto from a guarantee that prohibited boundaries will never appear. They do not
prove failure for arbitrary feasible requests. A wrapper can detect and reject
the result, but rejection does not construct a compliant alternative.

Core Text's explicit line constructor preserves the supplied ranges. An eight-M
line requested at a 20 pt measure remains intact and overfull; the probe records
the overflow. The caller rejects an unapproved break and a combining-sequence
midpoint before construction. Those checks belong to Folio, not Core Text.

Neither probe implements a hyphenation dictionary. TeX's language patterns and
a matcher can supply opportunities independently of the rendering framework.
Language-specific replacement spelling needs richer discretionary substitutions
than a soft-hyphen-only adapter. The [hyphenation research](../../../../docs/research/2026-09-27-textkit2-hyphenation-and-composition-controls.md#what-a-tex-pattern-source-actually-supplies)
records candidate engines, language variants, and separate code/data licenses.

### 2. Breaking and spacing: inputs versus optimization

Both engines accept fixed tracking and horizontal font transforms. The unsupported
TextKit 2 `NSExpansionAttributeName` is therefore insufficient grounds for choosing
Core Text: a fixed `NSFont` transform works in this experiment.

For four Hs with 0.5 pt tracking, Core Text reports 1.5 pt additional distance to
the fourth glyph origin. TextKit 2 reports a 2 pt increase in line width. Both
report different caret spacing conventions, so caret coordinates must not be
presented as glyph origins. Neither experiment proves acceptable spacing for
ligatures, marks, or connected scripts.

The architectural requirement is to choose these adjustments together with
line breaks under explicit limits. No user-supplied paragraph cost function was
found in the inspected TextKit 2 interfaces. Core Text also does not supply that
optimizer: its justified-line API takes a factor and width, without parameters
for Folio's minimum/ideal/maximum spacing policy. Exact policies may require
Folio-owned positioning as well as break selection. [Apple justification][justify]

### 3. Microtypography: measured geometry

Core Text's native hanging-punctuation option moved the opening quotation
mark's ink edge left by 5.326 pt while the frame origin stayed fixed. The saved
[native hanging image](evidence/hanging-built-in.png) shows the plain and hanging
variants against the same margin guide. This is a native edge rule, not a
user-defined percentage table. [Apple hanging punctuation][hanging]

For custom positioning, the probe first shapes a complete line, then extracts its
glyphs, positions, source indices, and run fonts. Moving only the opening quote by
0/50/100 percent of its advance produces independently measured raster shifts of
0/-2.75/-5.5 pt, within 0.35 pt of the requested 0/-2.663/-5.326 pt at 4× scale.
The interior ink bounds stay fixed at 5.5–77.75 pt. The [quote-only image](evidence/quote-only-glyph-positioning.png)
shows that result. This is Folio-controlled glyph drawing; it does not establish
a complete protrusion policy for arbitrary scripts.

TextKit 2 also passes a limited quote-only construction. Reducing the first-line
indent by 0.5/1 pt and adding the same amount of kerning to the opening quote
moves its ink by exactly that amount. All following horizontal ink runs remain
fixed in the 8× raster measurement. The following caret moves by half the
adjustment because caret boundaries differ from glyph origins.
Compare the saved [baseline](evidence/punctuation-left.png),
[0.5 pt variant](evidence/punctuation-indent-half.png), and
[1 pt variant](evidence/punctuation-indent-one.png).

The initial attempt incorrectly supplied zero tracking as well as nonzero quote
kerning. Apple's documented attribute precedence suppresses that kerning when
both keys are present. The corrected probe omits tracking for these cases. The
earlier failure is not evidence against the native construction. This proves a
first-line technique; it does not implement arbitrary punctuation rules at every
line edge. [Apple tracking and kerning precedence][tracking]

Custom geometry also requires corresponding selection, hit testing, copy,
accessibility, and export geometry. These standalone drawing experiments do not
provide those integrations.

## What math and uncommon scripts change

TextKit 2 already uses Core Text for text rendering. Choosing Core Text does not
automatically add script coverage or better language shaping. Font coverage,
context at line boundaries, combining marks, bidirectional runs, and editorial
conventions need representative fixtures. [Apple TextKit 2 architecture][tk2]

Mathematical composition needs another component. OpenType's `MATH` table
supplies constants, glyph metrics, and stretch constructions for recursive
formula layout; ordinary paragraph shaping does not implement that algorithm.
The compositor must accept formula dimensions and baselines and preserve their
semantics for interaction and output. [OpenType MATH specification][math]

## Next bounded proof

Implement a single-paragraph Core Text compositor with a supplied break set,
explicit spacing limits, and a paragraph-wide objective. Compare it against the
existing TextKit 2 specimens using the same text, fonts, widths, and candidates.
Require complete source mapping, measured constraint compliance, declared
infeasibility, and visual acceptance before extending it to pagination. Add
representative formula and complex-script fixtures as separate acceptance gates.

This answers whether Folio can own the required controls. It does not yet prove
that Folio's algorithm matches TextKit 2's typographic quality or editing behavior.

## Evidence

- [TextKit 2 results](textkit-results.json): 17 cases, complete source coverage;
  15 contracts met and two unmet infeasible break constraints.
- [Core Text results](coretext-results.json): eight passing cases and one
  whole-line offset demonstration. [Detailed notes](coretext-notes.md) distinguish
  that demonstration from the quote-only raster measurement.
- [Run metadata](run-evidence.json) records source/result hashes and toolchain.
- [Reproduction instructions and scope](README.md).

The native programs compiled with `-Wall -Wextra -Werror`. Measurements apply to
Times-Roman 12 pt on the recorded OS; older OS versions and additional fonts were
not tested in this control experiment.

[justify]: https://developer.apple.com/documentation/coretext/ctlinecreatejustifiedline(_:_:_:)
[hanging]: https://developer.apple.com/documentation/coretext/ctlineboundsoptions/usehangingpunctuation
[tracking]: https://developer.apple.com/documentation/coretext/kcttrackingattributename
[tk2]: https://developer.apple.com/videos/play/wwdc2021/10061/
[math]: https://learn.microsoft.com/en-us/typography/opentype/spec/math
