// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import CoreGraphics
import CoreText

struct DrawingRun {
    let font: CTFont
    let glyphs: [CGGlyph]
    let positions: [CGPoint]
}
