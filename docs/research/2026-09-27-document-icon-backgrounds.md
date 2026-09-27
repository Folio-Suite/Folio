<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

# Document-icon background directions

Research date: **27 September 2026**. Supports [issue #26](https://github.com/Folio-Suite/Folio/issues/26). This records visual research and the user-selected direction; the selected assets have been generated, with a native current-OS rendering probe completed and actual Folio Finder verification still pending. It extends the [document-icon pipeline research](2026-09-26-document-icon-pipeline.md).

## Accepted result

The user selected the combined wash and edge treatment with the archive zipper in the **upper-left**, inset from the bar. Badges fit their visible bounds without stretching. At 16 points the background is clear; at 32 points it contains only the bar; at 128 points and larger it adds the alpha fade and, for archives, the zipper. The stages below retain the research and native-mask findings that led to this result.

## Composition contract

`UTTypeIconBackgroundName` names an asset-catalog icon set. macOS scales it into the document canvas, masks it to the page, and draws the fold over its upper-right corner. Background art therefore does not need its own page silhouette or fold. The property's current documentation metadata gives macOS 11.0 availability. [Apple background property][background]; [property metadata][background-json]

The background can accompany Folio's existing badge and text: `UTTypeIcons` accepts any combination of background, badge, and label. An omitted background means no custom fill; an omitted badge selects the app icon; omitted text selects the extension. **Removing the badge key is not a documented way to remove the badge.** The inspected sources do not specify a portable empty-string suppression contract. [Apple composition dictionary][icons]

Apple's HIG explicitly recommends simple forms and limited colors, keeping important content away from the white fold, and reducing small-size detail. It presents both background-only and background-plus-badge examples. [Apple HIG][hig]

## Small reference set

The images below were visually inspected from their first-party sources. The observations describe published artwork; they do not establish the registration keys used by each shipping app or their appearance on every macOS release.

| Reference | Observed treatment | Useful lesson for Folio |
| --- | --- | --- |
| [Apple's heart composition example][heart-image] | Pink grid fades toward a pale lower area; large red heart sits above the label; white fold remains conspicuous. | A quiet label area and stronger upper field can coexist with a separate badge. Avoid copying its medical grid literally. |
| [Xcode project, published in Apple's HIG][xcode-image] | Saturated blue field, fine blueprint lines, inset border, white fold, small lower label. | A full-page color field gives strong type recognition, but detailed linework makes small-size simplification important. |
| [TextEdit rich-text example in Apple's HIG][textedit-image] | Typography and an inset photograph occupy the sheet itself, behind the fold. | Backgrounds can depict the document's subject instead of repeating the app icon. This is a HIG design example, not evidence of a particular file's generated thumbnail. |
| [BBEdit's Finder screenshot, 27 January 2023][bbedit-image] | White folded pages carry a compact purple B and gray TEXT label; a neighboring unassociated file is blank. | A restrained page leaves the badge legible. A subtle Folio fill should add recognition without making the existing foreground harder to read. |

Apple explicitly identifies Xcode and TextEdit as examples using background artwork without a center image. [Apple HIG][hig] Bare Bones separately documents that Finder's **Show icon preview** setting switches between file-content thumbnails and the application/system document icons. Its [comparison screenshot][bbedit-preview] is useful when preparing a fair Finder evaluation. [Bare Bones technical note][bbedit]

This selection deliberately uses three Apple examples and one third-party Finder example. Sketch's [Copenhagen article][sketch] includes document-type symbols, but identifies them as document-tab UI; it does not establish Finder background composition. No claim about Affinity's or Pixelmator's current file-icon artwork is needed here.

## Recommendation for comparison

Compare three treatments using the same current amber nib, violet book, and cobalt layout badges and existing labels:

1. **Plain page:** preserve the current no-fill rendering as the control.
2. **Quiet tint (Porcelain wash):** use a pale domain-colored wash gathering near the foot, with a nearly white center behind the badge. This is the recommended first candidate: it adds color without another competing shape. Unlike Apple’s heart example, this study concentrates the tint below; the label remains dark on a pale field.
3. **Colored edge:** a narrow app-colored strip along the left edge, with a neutral center. This gives a stronger small-size cue, but can suggest a folder spine or stationery. It is the alternative when fast recognition matters more than subtlety.

Sparse text rules or layout guides were considered as a further direction, but deferred: they add detail around symbols whose tiny-size clarity was already carefully tuned.

These are Folio design judgments, not Apple requirements. Use one shared treatment across the Suite and judge color, shape, and label together; color alone should not carry the distinction. A saturated full-page option is a useful upper bound, but the existing colored badges may lose contrast against it.

## Comparative mockups

Open the self-contained [interactive comparison](assets/2026-09-27-document-icon-backgrounds.html). It embeds the accepted size-specific PNG badges, with controls for app, 16/32/128/256-point size, Document/Archive, and light/dark surroundings. It requires no remote assets. The page/fold geometry, label, and placement are illustrative approximations, not Finder captures. The baseline represents the current design direction rather than an exact pixel match to macOS.

In the inspected mockups, the wash is subtle at 16/32 points and mainly adds character at 128/256 points. The colored edge is more conspicuous at small sizes, but introduces a second shape cue. All treatments leave the upper-right fold clear; the initial comparison retained the old large archive zipper badges; the selected D refinement now moves that indicator into its background. The same light palette is shown on both surroundings, without asserting dark-appearance asset selection. The wash keeps a neutral area behind the colored badge and a pale enough foot for the dark label, but native composition must confirm the result.

The comparison controls were exercised for Write and Composer at larger sizes and Research at 32 points, including archive and dark-surrounding switches; the browser reported no script errors. This checks the comparison artifact, not native rendering.

## Selected direction — combined wash and edge

The user selected B and C together: the app-colored edge plus a color-to-transparent gradient. Keep the hue constant and vary alpha; do not blend toward opaque white or paint a paper color into the background artwork. The system supplies the page and fold. This avoids baking in an assumption of white paper, but does not establish future macOS dark-document behavior or guarantee sufficient contrast on an unknown future palette.

| Logical icon size | Background treatment |
| --- | --- |
| 16 pt, including 16 pt @2x | None: no gradient or bar |
| 32 pt, including 32 pt @2x | Bar only, otherwise transparent |
| 128 pt and larger, at both scales | Bar plus alpha fade, otherwise transparent |

These thresholds map the user's tiny/small/large rule to the existing catalog slots. Preserve the current badge shapes, per-size simplifications, and labels. The subsequent user refinement fits badges to their visible bounds and moves the archive zipper into the lower-right background, where it can be larger. Both types share one badge; only their backgrounds differ. The updated comparison puts **D · Wash + edge** first while retaining A/B/C for reference. At the smallest size, D deliberately matches the plain-page baseline; at 32 pt, it matches the edge-only study. No extra per-size registration or new file identity is implied. The updated D preview uses the generated background PNGs and tightly fitted badges; A/B/C remain earlier background concepts using the updated badges.

## Implementation checks

The selected treatment is now generated into paired background icon sets and registered alongside one shared badge per app. The renderer measures the visible badge bounds, fits the longer axis without stretching, and preserves a full transparent canvas for backgrounds. The ZIP overlay is generated only in archive backgrounds at 128 points and larger. The user subsequently selected a compact lower-right zipper with a broad pull and fewer, thicker teeth, taking visual inspiration from the [Archive Utility reference](https://www.macosicongallery.com/icons/archive-utility-2026-09-23/). The reference was visually inspected; this third-party gallery is an artwork reference, not evidence of Apple API behavior. Folio places its own drawing beside the centered label, away from the badge and fold.

A coordinated unsigned Xcode 27 Suite build passed. Pixel checks covered all 30 badge PNGs (long-axis edges reached) and all 60 background PNGs (dimensions, clear 16-point slots, bar-only 32-point slots, and alpha retained in the large fade). Compiled metadata references the shared badge and correct native/archive background for all three apps. These checks do not replace the native visual trial below.

## Native composition follow-up

Xcode built the selected Write scheme successfully. A disposable type identity using its compiled catalog was rendered through `NSWorkspace` at 16, 32, 128, and 256 pixels. The first probe revealed that macOS clips the square background into a narrower page, hiding a bar at the extreme canvas edge and clipping the zipper. The corrected assets place the bar at x=176 on the 1024-unit canvas and fit the zipper within the lower-right visible area, above the system's larger text label. The second probe visibly retained the bar, symbol, fade, fold, and zipper; the 32-pixel document retained its bar without a fade or zipper.

This is current-OS native icon rendering evidence using a disposable identity, not a save/open test or confirmation of existing Folio associations. It does not establish the page mask geometry on every OS. The comparison was adjusted to approximate the observed geometry; it remains an illustration rather than a Finder screenshot.

## Limits and next evidence

An eventual background trial should retain the current registration fields and add only the named background icon set. Verify Finder icon and list views and an Open/Save panel, including light/dark surroundings and a size where label/detail disappears. Record whether icon previews are enabled. Test both the supported minimum macOS and current macOS before making a compatibility claim. The previous current-machine Finder smoke result covers the existing badge configuration, not these backgrounds.

[hig]: https://developer.apple.com/design/human-interface-guidelines/icons#macOS
[icons]: https://developer.apple.com/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons
[background]: https://developer.apple.com/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons/uttypeiconbackgroundname
[background-json]: https://developer.apple.com/tutorials/data/documentation/bundleresources/information-property-list/utexportedtypedeclarations/uttypeicons/uttypeiconbackgroundname.json
[heart-image]: https://developer.apple.com/tutorials/images/com.apple.HIG/doc-icon-parts@2x.png
[xcode-image]: https://developer.apple.com/tutorials/images/com.apple.HIG/doc-icon-custom-1@2x.png
[textedit-image]: https://developer.apple.com/tutorials/images/com.apple.HIG/doc-icon-fill-only@2x.png
[bbedit]: https://www.barebones.com/support/technotes/FinderPreviewIcons.html
[bbedit-image]: https://www.barebones.com/support/technotes/StandardIcons.png
[bbedit-preview]: https://www.barebones.com/support/technotes/ThumbnailIcons.png
[sketch]: https://www.sketch.com/blog/a-tour-of-copenhagen/

## Placement refinement — upper-left trial

The user requested an upper-left comparison after reviewing the native lower-right version. The same zipper is now inset from the colored bar, above and to the left of the badge. Its canvas bounds are approximately x=240–335 and y=120–331 on the 1024-unit background. Size thresholds and artwork remain unchanged; this moves the packaging cue away from the label. Earlier lower-right observations above describe the preceding iteration.

The upper-left variant passed the Xcode Write build and all 60 background checks. A fresh native NSWorkspace rendering visibly placed the zipper inside the page mask, clear of the fold, central nib, and label. This is a current-OS Write rendering check, not a claim about every app or supported OS.
