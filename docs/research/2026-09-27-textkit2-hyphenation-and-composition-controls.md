<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# TextKit 2, external hyphenation, and composition control

Research date: **27 September 2026**. This extends the [native paragraph research](2026-09-26-native-paragraph-composition.md) for [ADR 0012](../adr/0012-semantic-publication-and-native-composition.md). It is a research recommendation, not a new architecture decision or an implementation claim.

**Follow-up:** the later [composition control experiments](../../Composer/Prototypes/ParagraphComposition/Controls/FINDINGS.md)
address the expanded requirement for enforceable breaks and microtypographic
geometry. They refine the initial TextKit 2-first recommendation below toward a
Folio-owned compositor above Core Text. The original investigation is retained
to distinguish the earlier candidate-injection question from the later policy
requirements. Neither recommendation is an adopted architecture decision.

## Answer and evidence boundary

**TextKit 2 can plausibly remain Folio's native composition baseline while Folio supplies language-specific hyphenation opportunities.** Unicode soft hyphen (U+00AD) is an invisible discretionary intraword break marker. It need not appear in the canonical Work text: a derived attributed composition string could contain opportunities calculated from a selected pattern set. TextKit 2's public delegate can *allow or prevent* a candidate soft break or automatic hyphenation point; its documented return value cannot create a new candidate or direct a paragraph-wide scoring function. [Unicode UAX #14][unicode-shy]; [Apple TextKit 2 delegate][tk-delegate]; [installed macOS 27 SDK header][sdk-manager]

A local macOS 27/Latin Modern 12 probe by the parallel native investigation inserted four hand-chosen soft hyphens into a **derived** Latin fixture. TextKit 2 used two of those breaks at a 240-point measure and one at 300 points with automatic hyphenation disabled; unused markers were invisible. This proves the narrow mechanism on that fixture, font, and OS. It does **not** validate TeX pattern results, a general language adapter, text editing and selection maps, or any paragraph/page objective. The probe artifacts are temporary: `/tmp/folio-discretionary-probe.json`, `/tmp/folio-ct-appkit-probe/results.json`, and related PNGs. The chosen Latin breaks were not checked for linguistic correctness.

**The available evidence does not require a Core Text compositor now.** Apple's TextKit 2 has its own documented even line-breaking behavior for justified paragraphs. A direct Core Text framesetter or successive typesetter-break/justify loop does not establish that TextKit 2's visual quality cannot be met or exceeded with a controlled Core Text paragraph algorithm. Conversely, a good TextKit 2 screenshot does not establish that its public controls can satisfy every Composer Profile or whole-page constraint. Evaluate both with matched attributes, fonts, language and discretionary candidates before choosing a production compositor. [Apple WWDC22][tk22]; [Apple Core Text typesetter][ct-typesetter]; [Apple Core Text justification][ct-justify]

## Matching the native look

An additional local probe passed the harness's AppKit attributed paragraph
settings into the Core Text framesetter instead of constructing a
`CTParagraphStyle`. With Latin article 1, Latin Modern Roman 12, all three
measures, and both requested hyphenation settings, Core Text's break sequences
remained identical to the earlier Core Text baseline. This rules out that
particular attribute substitution as a way to select TextKit 2's behavior; it
does not exhaust Core Text's controls. The scratch source is
`/tmp/folio-ct-appkit-attributes.m`.

Core Text also has public hanging-punctuation and optical-bound options through
`kCTParagraphStyleSpecifierLineBoundsOptions`. Those provide useful native
building blocks, but do not expose arbitrary protrusion tables or automatically
coordinate font expansion with paragraph-wide break selection. Tracking is an
explicit adjustment; nonzero Core Text tracking disables nonessential ligatures
unless overridden. Setting kerning to zero disables standard kerning rather
than selecting a neutral typography preset. [Apple line-bound options][ct-bounds];
[Apple tracking][ct-tracking]; [Apple kerning][ct-kern]

## What a TeX-pattern source actually supplies

The [hyph-utf8 collection][hyph-utf8] contains UTF-8 patterns derived from many language projects; Babel is a larger TeX language environment with rules beyond patterns. Its Latin extension exposes different language variants and typographic controls. Pattern matching follows Liang's method: match overlapping letter/digit patterns against a word with boundary markers, retain the highest digit at each interletter position, and permit positions with odd values after language-specific left/right minima and exceptions. A port must also handle Unicode normalization/case mapping, punctuation and compound words, and source-to-rendered offset conversion; a bare pattern file is not a complete multilingual policy. [hyph-utf8 README][tex-hyphen]; [LibHnj algorithm description][libhnj-algorithm]; [Babel][babel]; [Babel-Latin][babel-latin]

Latin is a useful optional test case, not an architecture gate. The collection currently lists modern/medieval `hyph-la.tex`, classical `hyph-la-x-classic.tex`, and liturgical `hyph-la-x-liturgic.tex`; the modern/medieval file describes its spelling scope and has explicit 2/2 minima. Folio should select the variant to fit the actual source and editorial policy, rather than assume a generic `la` locale settles it. [hyph-utf8 Latin directory][latin-directory]; [modern/medieval Latin source][latin-source]; [Babel-Latin][babel-latin]

### Code and pattern licensing are separate

The upstream repository says its default license is MIT **except** for several core `hyph-*.tex` pattern files and derivatives. CTAN's package-level MIT label cannot clear every language for redistribution. The modern/medieval Latin file expressly offers **MIT or LPPL**; the American English file uses its own permission notice. A shipping language set needs a file-by-file license inventory, retained copyright/notices, pinned upstream revision, and separate review of generated data. No blanket claim about all patterns follows from the package page. [repository license statement][tex-hyphen]; [Latin source][latin-source]; [American English source][english-source]; [CTAN package record][hyph-utf8]

Possible engines are distinct from data rights. [LibHnj/libhyphen][libhyphen] is a C implementation for converted TeX patterns with compound and nonstandard hyphenation support; its README states LGPL/GPL/MPL choices. [Typst's `hypher`][hypher] is Rust code dual-licensed MIT/Apache-2.0, with embedded language patterns carrying their own licenses and selectable features. Neither is an automatic Folio dependency recommendation: compare integration cost, supported pattern syntax and exceptions, Unicode offsets, and the exact pattern notices before adoption. A small project-owned Liang matcher is also feasible, but needs conformance tests against the chosen language files. [LibHnj algorithm/readme][libhnj-algorithm]; [Libhyphen licensing][libhyphen]; [`hypher` licensing and features][hypher]

## TextKit 2 integration questions

- **Candidate injection:** U+00AD in derived layout text is a plausible bridge from pattern output to native breaking. Unicode explicitly leaves the displayed result at a chosen hyphenation point language dependent; some languages need spelling changes or another mark. The Latin probe verifies ordinary visible hyphens only. [Unicode UAX #14][unicode-shy]
- **Document identity and indexes:** inserting markers shifts `NSString` UTF-16 offsets and TextKit 2 locations relative to Work content. A reversible canonical-to-layout map must cover selection, hit testing, copy/paste, accessibility, annotations, search, revision targets, and edits. This is an **inference and required experiment**, not an existing Folio implementation. It may be preferable to regenerate only the affected paragraph's derived string on edits.
- **Delegate scope:** the installed SDK describes `shouldBreakLineBeforeLocation:hyphenating:` as a decision on a break location that the manager is considering; `hyphenating:YES` identifies an automatic point. It provides a veto, not an arbitrary insertion callback. A delegate cannot by itself guarantee a chosen complete sequence of line breaks. [Apple delegate][tk-delegate]; [SDK header][sdk-manager]
- **Microtypography:** native font features, optical sizes, tracking, and Core Text line-bound options are real controls. They do not amount to a documented TextKit 2 interface for user-supplied per-glyph protrusion tables, bounded per-line expansion, or custom paragraph/page demerits. This is a limit of the inspected public API, **not a proof that TextKit 2 can never produce the desired look**. See the [prior control matrix](2026-09-26-native-paragraph-composition.md#api-and-control-matrix) and compare actual output before implementing a separate compositor. [Apple WWDC22][tk22]; [Apple TextKit 2 layout manager][tk-manager]

## Recommended next proof

Keep TextKit 2 as the first comparison target. On one agreed specimen, record exact font files, language variant, pattern version and license, normal and discretionary source strings, candidate and selected breaks, and text-to-layout index mapping. Compare TextKit 2 with and without injected candidates, then a **paragraph-wide** Core Text candidate search using the same attributed input and break set. Judge typographic gray, repeated hyphens, correctness, edit/selection behavior, and performance; a raw framesetter result is only a baseline. Introduce a Core Text-owned compositor if the measured TextKit 2 control or quality limit justifies its added layout lifecycle work. Latin can remain optional while the first composition decision is tested with a language for which provenance and rights are settled.

[unicode-shy]: https://www.unicode.org/reports/tr14/#SoftHyphen
[tk-delegate]: https://developer.apple.com/documentation/appkit/nstextlayoutmanagerdelegate/textlayoutmanager(_:shouldbreaklinebefore:hyphenating:)
[sdk-manager]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSTextLayoutManager.h
[tk22]: https://developer.apple.com/videos/play/wwdc2022/10090/
[tk-manager]: https://developer.apple.com/documentation/appkit/nstextlayoutmanager
[ct-typesetter]: https://developer.apple.com/documentation/coretext/cttypesetter
[ct-justify]: https://developer.apple.com/documentation/coretext/ctlinecreatejustifiedline(_:_:_:)
[hyph-utf8]: https://ctan.org/pkg/hyph-utf8
[tex-hyphen]: https://github.com/hyphenation/tex-hyphen
[libhnj-algorithm]: https://github.com/hunspell/hyphen/blob/master/README.hyphen
[babel]: https://ctan.org/pkg/babel
[babel-latin]: https://ctan.org/pkg/babel-latin
[latin-directory]: https://github.com/hyphenation/tex-hyphen/tree/master/hyph-utf8/tex/generic/hyph-utf8/patterns/tex
[latin-source]: https://github.com/hyphenation/tex-hyphen/blob/master/hyph-utf8/tex/generic/hyph-utf8/patterns/tex/hyph-la.tex
[english-source]: https://github.com/hyphenation/tex-hyphen/blob/master/hyph-utf8/tex/generic/hyph-utf8/patterns/tex/hyph-en-us.tex
[libhyphen]: https://github.com/hunspell/hyphen
[hypher]: https://github.com/typst/hypher
[ct-bounds]: https://developer.apple.com/documentation/coretext/ctparagraphstylespecifier/lineboundsoptions
[ct-tracking]: https://developer.apple.com/documentation/coretext/kcttrackingattributename
[ct-kern]: https://developer.apple.com/documentation/coretext/kctkernattributename
