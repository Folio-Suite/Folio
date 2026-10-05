# ``TypographyKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Compose exact caller-selected lines with Core Text and inspect the geometry and
source relationships used to draw them.

## Overview

``TypographyComposer/compose(_:)`` accepts an immutable ``CompositionRequest`` and
returns a ``CompositionResult``. Text is supplied as ``TextOccurrence`` values;
repeated source IDs remain distinct through occurrence indices. Breaks index
UTF-16 in the concatenated original text, increase strictly, and end at its
length. A discretionary supplies before-break, after-break, and no-break
material while preserving the original source.

The synchronous operation validates selected breaks, required and forbidden
boundaries, grapheme and shaping-cluster positions, font resolution, and the
supported adjustment limits. Its ``CompositionStatus`` explicitly distinguishes
complete results from unsupported requests and infeasible selected geometry.
A caller can submit another request when a page or region changes. TypographyKit
does not search break sequences or own a Folio Document.

The public declarations and their DocC comments are in
`Interface/TypographyKit.swift`. `Modules/Composition/` contains implementation details.

```swift
import CoreGraphics
import Foundation
import TypographyKit

func drawPassage(in context: CGContext) -> CompositionResult {
    let request = CompositionRequest(
        occurrences: [TextOccurrence(sourceID: "passage", text: "extraordinary")],
        fontPostScriptName: "Times-Roman", fontSize: 12,
        lineWidth: 100, lineHeight: 16, breaks: [5, 13],
        discretionaries: [Discretionary(boundary: 5,
            replacementRange: NSRange(location: 5, length: 0), beforeBreak: "-")])
    let result = TypographyComposer.compose(request)
    guard result.status == .complete else { return result }
    // Lines read "extra-" and "ordinary"; originalText remains "extraordinary".
    // The caller provides a Y-up context and owns its paint state.
    let savedTextMatrix = context.textMatrix
    context.saveGState()
    result.draw(in: context, at: CGPoint(x: 20, y: 100))
    context.restoreGState()
    context.textMatrix = savedTextMatrix
    return result
}
```

``ComposedLine`` exposes source and rendered ranges, mappings, glyph positions,
caret positions, advance, baseline, and ink bounds. ``CompositionProvenance``
records the engine, OS, requested and actual fonts, and requested font version.
The result retains Core Text fonts and glyphs privately so drawing and reported
geometry describe the same composition. The caller owns the graphics context.
The result is an immutable reference value and has no unchecked `Sendable`
conformance; transfer across concurrency boundaries remains the host's decision.

## Read coordinates and source relationships

All offsets and ranges count UTF-16 code units. Use `text.utf16.count` or
`(text as NSString).length` when constructing offsets; `text.count` counts Swift
characters and can differ for combining text. Even a valid UTF-16 offset is not
necessarily a legal grapheme or shaping boundary. The composer validates
boundaries against the original text before discretionary material and line
adjustments are applied.

| Value | Coordinate or index space |
| --- | --- |
| ``CompositionRequest/breaks``, ``ComposedLine/sourceRange`` | Concatenated original source, UTF-16 |
| ``SourceMapping/sourceRange`` | One original occurrence, UTF-16 |
| ``SourceMapping/renderedRange``, ``GlyphGeometry/renderedUTF16Offset`` | One rendered line, UTF-16 |
| ``ComposedLine/baseline`` | Result coordinates in points, Y-up |
| ``GlyphGeometry/position``, ``ComposedLine/inkBounds`` | Points relative to the line baseline |
| ``ComposedLine/caretOffsets`` | Baseline-relative x positions, one per rendered code-unit offset plus the end |

To place glyph geometry or ink bounds, add the line's baseline and the origin
passed to ``CompositionResult/draw(in:at:)``. The first baseline is at zero;
later baselines have decreasing y values, separated by the supplied line height.
A flipped view must arrange the destination coordinate transform. Drawing uses
the context's paint state and does not clip overfull lines to the requested width.
It can change the context's font, text size, and text matrix. Preserve the font
and size with graphics-state saving and restoration, and restore `textMatrix`
separately; the matrix is outside the graphics-state stack.
See [Apple's glyph drawing contract](https://developer.apple.com/documentation/coretext/ctfontdrawglyphs(_:_:_:_:_:)).
Apple's [text-matrix contract](https://developer.apple.com/documentation/coregraphics/cgcontextsettextmatrix)
explains why restoring the graphics state alone is insufficient.

Map rendered fragments through ``ComposedLine/mappings`` rather than assuming
rendered offsets equal source offsets. ``MappingKind/source`` preserves text,
while inserted, substituted, and omitted fragments can have unequal source and
rendered lengths. Insertions carry zero-length source anchors; omissions carry
zero-length rendered ranges. Match ``SourceMapping/occurrenceIndex`` as well as
the host's source ID when the same source appears more than once. Glyph indices
describe shaping, while caret offsets describe insertion geometry; neither
provides a native selection or accessibility implementation.

## Supported behavior and limits

This first operation supports explicit left-to-right Latin text, a resolved
PostScript font, exact break realization, insertion/omission/substitution
mappings, fixed tracking, positive interior ASCII-space adjustment, bounded
horizontal expansion, and bounded opening-quote protrusion. It preserves the
original Unicode sequence and does not normalize text. Fallback requires an
explicit opt-in and the result reports actual font names.

It does not generate language opportunities, optimize a paragraph, compose
mathematics or complex scripts, implement bidirectional layout, or provide native
editing and accessibility hosting. Constraints that are not met yield
`infeasible`; unsupported controls yield `unsupported`. Consumers should use
``CompositionDiagnostic`` codes for localized explanations and never treat a
drawn line as proof of publication readiness.

A font fallback that the caller disallows produces `infeasible`: the requested
font constraint cannot be satisfied. Allowing fallback retains the actual fonts
and versions in provenance without making fallback alone a failure.

The requested font must still resolve to its PostScript name: allowing fallback
does not authorize replacing an unavailable requested font with a best match.
Tracking uses Core Text's added points per character cluster and can suppress
nonessential ligatures. Space adjustment affects rendered ASCII spaces except a
final space; it does not distribute a target justification width. Protrusion
moves a supported opening quote glyph without changing logical caret offsets.

Inspect status and diagnostics on every attempt. ``CompositionStatus/unsupported``
returns no lines. An infeasible result may also have no lines when break
constraints are rejected, or may retain all selected lines when their measured
width, height, glyph availability, or fallback policy fails. The composer does
not throw or retry with different breaks. Diagnostic messages are developer
wording; use ``DiagnosticCode`` to supply the host's localized explanations.

## Topics

### Request exact lines

- ``TypographyComposer``
- ``TypographyComposer/compose(_:)``
- ``CompositionRequest``
- ``TextOccurrence``
- ``Discretionary``
- ``CompositionAdjustments``

### Inspect acceptance and provenance

- ``CompositionResult``
- ``CompositionStatus``
- ``CompositionDiagnostic``
- ``DiagnosticCode``
- ``CompositionProvenance``

### Interpret geometry and source mappings

- ``ComposedLine``
- ``GlyphGeometry``
- ``SourceMapping``
- ``MappingKind``

### Draw retained geometry

- ``CompositionResult/draw(in:at:)``
