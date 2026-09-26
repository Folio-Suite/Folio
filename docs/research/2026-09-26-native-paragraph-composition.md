<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Native paragraph composition: evidence and a bounded proof

Research date: **26 September 2026**. Context: the ongoing composition architecture interview for issue #12. This is an evidence report, not an architecture decision or an implementation authorization.

The subsequently approved [composition and publication contract](../architecture/composition-publication-contract.md) records the requirements and staged engine milestone. The candidates and API controls below remain subject to experiments; documenting their availability does not establish the required output quality.

The requested floor is **whole-paragraph composition**; whole-page optimization is the further goal. The quality target is even typographic gray/color: balanced visual texture without conspicuously loose or tight lines. The agreed specimen is the **first question of the *Summa Theologiae***. Its exact Latin source, translation, and edition remain unselected; no specimen text was selected, downloaded, or assigned a rights status in this research.

## Finding

Apple supplies more than shaping followed by ordinary independent line justification. In WWDC22, Apple specifically describes improved TextKit 2 line breaking for justified paragraphs, intended to reduce excessive word spacing and uneven lines; this behavior needs no separate adoption. That is positive evidence for evaluating native paragraph composition. It is **not** a published contract for a particular paragraph-wide search algorithm, an exposed scoring function, or a whole-page objective. [Apple, What's new in TextKit and text views][tk22]

Core Text supplies a clearer boundary for caller-controlled composition: a typesetter can create a line for a caller-selected string range, and another operation can justify that line. These primitives make a Folio-controlled paragraph search plausible while preserving native shaping. This is an **inference about a candidate design**, not proof of satisfactory results or effort. [Apple, CTTypesetterCreateLineWithOffset][ct-create]; [Apple, CTLineCreateJustifiedLine][ct-justify]

The decisive distinction is **choosing the sequence of breaks together** versus choosing each next break independently and then stretching that already-chosen line. Whole-paragraph evaluation can trade a slightly worse early line for better subsequent lines. Applying justification to successive independently selected lines does not, by itself, meet the requested floor. This defines the research question; it does not diagnose Apple's private implementation.

## Evidence scope and confidence

**Known** means explicitly supported by the cited public contract or Apple presentation. **Unsupported by inspected evidence** means the sources do not establish the claimed guarantee; it does not mean the implementation lacks that behavior. **Requires prototype** means the API exists but the needed quality, integration, or stability remains unproved.

Sources were current Apple documentation, relevant Apple WWDC presentations, Xcode documentation search, and the installed public headers. SDK inspected: **Xcode 27.0, build 27A266a; macOS SDK 27.0, canonical name `macosx27.0`**, rooted at `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk`. No layout was executed. Older WWDC statements establish documented design intent, not a current rendering regression test.

Local corroborating headers, with the inspected areas:

- Core Text: [CTTypesetter.h, lines 141–280][h-typesetter], [CTLine.h, lines 181–209][h-line], [CTParagraphStyle.h][h-paragraph], [CTStringAttributes.h, kerning/tracking/language][h-attributes], [CTFontDescriptor.h, features/variation/optical size][h-font].
- AppKit: [NSParagraphStyle.h, strategies/hyphenation/tightening][h-nsparagraph], [NSTextLayoutManager.h, hyphenation and delegate][h-manager], [NSTextLayoutFragment.h][h-fragment], [NSTextLineFragment.h][h-linefragment], [NSTypesetter.h][h-nstypesetter].
- Core Foundation: [CFString.h, lines 513–541][h-cfstring], for locale-specific hyphenation opportunities.

## API and control matrix

| Capability | Core Text | TextKit 2 / AppKit | Evidence boundary |
| --- | --- | --- | --- |
| Shaping and positioning | `CTTypesetter` performs glyph conversion, ordering, kerning, tracking, and baseline adjustments. | TextKit 2 renders through Core Text and abstracts glyph handling. | **Known.** Neither requires Folio to replace the native shaper. [CTTypesetter][ct-typesetter]; [WWDC21][tk21] |
| Select line breaks | `CTTypesetterSuggestLineBreak` suggests a contextual break for a start index and width; `CreateLine` accepts the selected range. Cluster-break suggestions preserve linguistic clusters but omit other contextual analysis. | Native even breaking for justified paragraphs; delegate can allow or veto candidate soft breaks and auto-hyphenation points. | **Known controls.** A delegate veto is not an exposed whole-paragraph cost function. [SuggestLineBreak][ct-break]; [SuggestClusterBreak][ct-cluster]; [delegate][tk-break]; [WWDC22][tk22] |
| Justify a chosen line | `CTLineCreateJustifiedLine` provides target width and justification factor; narrower widths request negative justification. | Paragraph alignment requests justification; native line breaking is distinct from that alignment setting. | **Known.** No caller-defined word-space minimum/ideal/maximum or paragraph demerit callback appears in these inspected contracts. [CTLine][ct-justify]; [paragraph alignment][alignment] |
| Hyphenation | Cluster-break primitives can support a custom scheme; Core Foundation supplies language-specific opportunities and an availability query. | `usesHyphenation`, paragraph `usesDefaultHyphenation`/`hyphenationFactor`, and the break delegate affect behavior. | **Known.** Correct support for the selected Latin/translation language is **unproved**. [CFString][hyph]; [usesHyphenation][uses-hyph]; [hyphenationFactor][hyph-factor]; [delegate][tk-break] |
| Paragraph strategies | `CTParagraphStyle` exposes alignment, indentation, tabs, line heights/spacing, writing direction, line-break mode, and line-edge bounds options. | `lineBreakStrategy` offers none, push-out, Hangul word priority, and standard. | **Known.** Standard targets short UI labels; it is not a documented scholarly composition mode. [CT styles][ct-paragraph]; [NS strategies][strategies]; [standard][standard] |
| Custom composed output | Caller-selected ranges become drawable, measurable `CTLine` objects. `CTFramesetter` fills a supplied path. | A delegate supplies custom layout fragments; line fragments have attributed-string/range initializers and drawing/mapping methods. | **Known primitives.** Seamless injection of independently optimized lines into TextKit 2's layout, selection, and invalidation remains **requires prototype**. [CTLine][ct-line]; [frames][frame]; [fragment delegate][fragment-delegate]; [line fragment][line-fragment] |
| Whole paragraph / whole page objective | Inspected public inputs describe line construction, paragraph styling, and frame filling. | Documented even paragraph breaking, but no exposed objective for Folio's page/stream constraints was found. | Native quality behavior is **known**; a guaranteed paragraph-global optimum or configurable page-global optimizer is **unsupported by inspected evidence**. [typesetter][ct-typesetter]; [frames][frame]; [WWDC22][tk22] |

### Spacing, language, and typography details

Core Text's kerning and tracking are real controls, with different semantics. Omitting the kern attribute preserves normal font kerning; explicitly setting it to zero disables kerning. Tracking adds cluster spacing and can disable nonessential ligatures unless overridden. These controls therefore cannot be treated as harmless interchangeable ways to adjust gray. Their quality limits need evaluation. [Apple, kCTKernAttributeName][kern]; [Apple, kCTTrackingAttributeName][tracking]; SDK `CTStringAttributes.h`.

AppKit's `allowsDefaultTighteningForTruncation` and `tighteningFactorForTruncation` concern avoiding **truncation**. They do not document a general paragraph-quality microtypography policy. Likewise, push-out addresses an orphan final word, and Hangul priority governs eligible breaks; those are useful policies without establishing a globally optimized sequence. [Apple, tightening][tighten]; [Apple, pushOut][pushout]; [SDK NSParagraphStyle.h][h-nsparagraph]

`kCTLanguageAttributeName` selects localized glyphs when the font supports them and locale-specific line-breaking rules. Core Foundation explicitly says hyphenation data is unavailable for some locales. The specimen's Latin and translation must therefore receive explicit language handling, with availability and editorially acceptable break points checked separately. Do not assume system language preferences produce the desired result. [Apple, language attribute][language]; [Apple, hyphenation][hyph]

Typography is not limited to choosing a font family. The inspected SDK documents AAT and OpenType feature settings, variation-axis values, and optical-size control; the optical-size attribute can activate size-specific metrics rather than simple scaling. TextKit 2 also explicitly supports OpenType and variable fonts. These are available inputs, not a promise that every font implements every feature or that arbitrary width/weight variation is typographically appropriate. [Apple, feature settings][features]; [Apple, variation][variation]; [Apple, optical size][optical]; [SDK CTFontDescriptor.h][h-font]; [WWDC22][tk22]

Record **Computer Modern and Latin Modern OpenType support as requested test cases**. The exact font files, versions, faces, optical designs, feature coverage, fallback behavior, and metrics must be recorded during the proof. Do not substitute one family for the other, or treat similarly named variants as metrically equivalent. No font package was installed or validated here.

### Custom fragments and older AppKit hooks

TextKit 2 explicitly permits a custom `NSTextLayoutFragment` for an element. Apple's example customizes drawing and bounds while retaining the system's text drawing. The public `textLineFragments` collection is read-only, and the inspected line-fragment initializer takes attributed text plus a range, not an already-composed `CTLine`. This does **not** prove that arbitrary composition integration is impossible. It means that “custom fragment” alone does not establish a supported replacement for the paragraph composer with correct selection, geometry, and invalidation. [Apple, fragment delegate][fragment-delegate]; [Apple, line fragment][line-fragment]; [SDK fragment headers][h-fragment]; [WWDC21][tk21]

Older AppKit has a more explicit custom-typesetter seam: Apple's `NSTypesetter` documentation says subclassing and overriding `layoutParagraphAtPoint:` integrates a custom engine into the Cocoa text system. It exposes paragraph ranges, line geometry, glyph positioning, and line/hyphenation hooks. This is valuable evidence that native hosting and custom composition can coexist. It belongs to the `NSLayoutManager` path, with glyph-level responsibilities; it is not interchangeable with the TextKit 2 fragment API. Apple recommends considering `NSTextLayoutManager` for newer systems in its `NSATSTypesetter` documentation. [Apple, NSTypesetter][old-typesetter]; [Apple, layoutParagraph][old-paragraph]; [Apple, NSATSTypesetter][ats]

## What Folio must still coordinate

**Inference from the API boundaries and Folio's domain contracts:** shaping, line measurement, and container filling do not determine the publication meaning of an Arrangement. Composer still needs to coordinate ordered Content Unit placements, stable source identities, multiple textual streams, anchors, and Note placement. Notes remain authored semantic content; placement as footnotes is a composition outcome. This preserves [CONTEXT.md](../../CONTEXT.md), [ADR 0009](../adr/0009-continue-cocoa-suite-with-domain-kits.md), and [ADR 0011](../adr/0011-composer-arrangements-and-editions.md).

For a page containing main text and footnotes, the coordinator must resolve how selected anchors reserve note space, how note continuation changes available main-text height, and when an earlier paragraph must be reconsidered. Parallel streams add alignment constraints; figures add exclusion geometry; generated Marks and Cross-references can change widths. Whole-page optimization needs an explicit choice of candidates, priorities, stopping rules, and failure diagnostics. Neither filling a Core Text frame nor laying out visible TextKit fragments establishes those Folio-specific rules. [Apple, frame filling][frame]; [Apple, TextKit element/viewport model][tk21]

No evidence here settles how much of that coordinator belongs in a reusable native layout adapter versus Composer-specific machinery. Consistent pagination, acceptable typography, and semantic traceability remain separate proof obligations.

## Recommended bounded proof — inference, not a decision

1. **Freeze the specimen inputs first.** Select the exact sources/edition for the first question of the *Summa Theologiae*, identify the chosen language streams and any editorial apparatus, and record permission/provenance separately. Agree on representative long paragraphs, measures, point sizes, and visible quality failures. This report selects none of those texts.
2. **Establish the native baseline.** Render identical attributed inputs with TextKit 2 justification and deliberate language/hyphenation settings. Capture complete paragraphs, line ranges, dimensions, break positions, and the actual active text engine. Compare Core Text framesetting under matched inputs without assuming it shares TextKit 2's paragraph behavior.
3. **Probe paragraph control only if needed.** Compare a small caller-controlled sequence search using Core Text line construction against the baseline. It must consider alternatives across the complete paragraph, with declared spacing/hyphenation limits and context-correct line shaping. A successive suggest-break/justify loop is only a comparison baseline. Evaluate custom-fragment integration separately if native editing/selection around those lines is required.
4. **Judge gray with both measurements and pages.** Inspect excessive word spaces, adjacent loose/tight lines, repeated hyphens, short final lines, visible rivers, and overall texture. Measure spacing variation, fallback, runtime, and sensitivity to small measure/text changes; human review remains necessary. Test the exact Computer Modern and Latin Modern OpenType variants separately. A good screenshot alone does not establish repeatability or paragraph-wide choice.
5. **Then probe a small page interaction.** Add one anchored Note and a controlled continuation case, plus a second stream only when specimen inputs are settled. Show whether the coordinator can revise paragraph choices when page space changes and terminate predictably. This tests the next architectural uncertainty without building a general publishing engine.

**Recommendation:** give TextKit 2 a fair native-quality evaluation first; retain Core Text as the explicit-control candidate. Keep the older typesetter seam as a comparison option if AppKit integration proves decisive. Accept or reject these candidates through evidence about control and output quality, without trying to identify Apple's internal algorithm. Nothing in this report lowers the whole-paragraph requirement or declares the whole-page goal achieved.

The proof should answer four explicit questions: Does native TextKit 2 meet the agreed paragraph-quality threshold on the specimen? Can Folio choose and compare complete alternative break sequences while retaining correct native shaping? Can those chosen lines participate in the required selection and layout lifecycle? Can a small footnote/page-space change trigger a bounded reconsideration that preserves semantic anchors? These remain open.

## Future fog (not researched or decided)

Possible licensing of Adobe commercial fonts such as **Minion Pro**, and potential paid **Theme packs**. Licensing/distribution terms and the business model remain open. This item is pinned for later investigation; no licensing research or decision was made here.

[tk22]: https://developer.apple.com/videos/play/wwdc2022/10090/
[tk21]: https://developer.apple.com/videos/play/wwdc2021/10061/
[ct-typesetter]: https://developer.apple.com/documentation/coretext/cttypesetter
[ct-create]: https://developer.apple.com/documentation/coretext/cttypesettercreatelinewithoffset(_:_:_:)
[ct-break]: https://developer.apple.com/documentation/coretext/cttypesettersuggestlinebreak(_:_:_:)
[ct-cluster]: https://developer.apple.com/documentation/coretext/cttypesettersuggestclusterbreakwithoffset(_:_:_:_:)
[ct-justify]: https://developer.apple.com/documentation/coretext/ctlinecreatejustifiedline(_:_:_:)
[ct-line]: https://developer.apple.com/documentation/coretext/ctline
[ct-paragraph]: https://developer.apple.com/documentation/coretext/ctparagraphstylespecifier
[frame]: https://developer.apple.com/documentation/coretext/ctframesettercreateframe(_:_:_:_:)
[tk-break]: https://developer.apple.com/documentation/appkit/nstextlayoutmanagerdelegate/textlayoutmanager(_:shouldbreaklinebefore:hyphenating:)
[fragment-delegate]: https://developer.apple.com/documentation/appkit/nstextlayoutmanagerdelegate/textlayoutmanager(_:textlayoutfragmentfor:in:)
[line-fragment]: https://developer.apple.com/documentation/appkit/nstextlinefragment
[alignment]: https://developer.apple.com/documentation/appkit/nsparagraphstyle/alignment
[strategies]: https://developer.apple.com/documentation/appkit/nsparagraphstyle/linebreakstrategy-swift.property
[standard]: https://developer.apple.com/documentation/appkit/nsparagraphstyle/linebreakstrategy-swift.struct/standard
[pushout]: https://developer.apple.com/documentation/appkit/nsparagraphstyle/linebreakstrategy-swift.struct/pushout
[tighten]: https://developer.apple.com/documentation/appkit/nsparagraphstyle/allowsdefaulttighteningfortruncation
[uses-hyph]: https://developer.apple.com/documentation/appkit/nstextlayoutmanager/useshyphenation
[hyph-factor]: https://developer.apple.com/documentation/appkit/nsparagraphstyle/hyphenationfactor
[hyph]: https://developer.apple.com/documentation/corefoundation/cfstringgethyphenationlocationbeforeindex(_:_:_:_:_:_:)
[kern]: https://developer.apple.com/documentation/coretext/kctkernattributename
[tracking]: https://developer.apple.com/documentation/coretext/kcttrackingattributename
[language]: https://developer.apple.com/documentation/coretext/kctlanguageattributename
[features]: https://developer.apple.com/documentation/coretext/kctfontfeaturesettingsattribute
[variation]: https://developer.apple.com/documentation/coretext/kctfontvariationattribute
[optical]: https://developer.apple.com/documentation/coretext/kctfontopticalsizeattribute
[old-typesetter]: https://developer.apple.com/documentation/appkit/nstypesetter
[old-paragraph]: https://developer.apple.com/documentation/appkit/nstypesetter/layoutparagraph(at:)
[ats]: https://developer.apple.com/documentation/appkit/nsatstypesetter
[h-typesetter]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/CoreText.framework/Headers/CTTypesetter.h
[h-line]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/CoreText.framework/Headers/CTLine.h
[h-paragraph]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/CoreText.framework/Headers/CTParagraphStyle.h
[h-attributes]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/CoreText.framework/Headers/CTStringAttributes.h
[h-font]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/CoreText.framework/Headers/CTFontDescriptor.h
[h-nsparagraph]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSParagraphStyle.h
[h-manager]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSTextLayoutManager.h
[h-fragment]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSTextLayoutFragment.h
[h-linefragment]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSTextLineFragment.h
[h-nstypesetter]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSTypesetter.h
[h-cfstring]: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/CoreFoundation.framework/Headers/CFString.h
