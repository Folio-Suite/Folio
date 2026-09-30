# ``TypographyKit``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

Compose exact caller-selected lines with Core Text and inspect the geometry and
source relationships used to draw them.

## Overview

`TypographyComposer.compose(_:)` accepts an immutable ``CompositionRequest`` and
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
let request = CompositionRequest(
    occurrences: [TextOccurrence(sourceID: "passage", text: "extraordinary")],
    fontPostScriptName: "Times-Roman", fontSize: 12,
    lineWidth: 100, lineHeight: 16, breaks: [5, 13],
    discretionaries: [Discretionary(boundary: 5,
        replacementRange: NSRange(location: 5, length: 0), beforeBreak: "-")])
let result = TypographyComposer.compose(request)
if result.status == .complete {
    // Result lines read "extra-" and "ordinary"; originalText is unchanged.
    result.draw(in: context, at: CGPoint(x: 20, y: 100))
}
```

``ComposedLine`` exposes source and rendered ranges, mappings, glyph positions,
caret positions, advance, baseline, and ink bounds. ``CompositionProvenance``
records the engine, OS, requested and actual fonts, and requested font version.
The result retains Core Text fonts and glyphs privately so drawing and reported
geometry describe the same composition. The caller owns the graphics context.
The result is an immutable reference value and has no unchecked `Sendable`
conformance; transfer across concurrency boundaries remains the host's decision.

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
