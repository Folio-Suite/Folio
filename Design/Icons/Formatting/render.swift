// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT

import AppKit
import CoreText

// Static SF Symbols template: preserve the semantic italic/bold design at each scale.
let directory = CommandLine.arguments[1]
for (name, weight, italic) in [("Emphasis", NSFont.Weight.regular, true), ("StrongEmphasis", NSFont.Weight.bold, false)] {
    let base = NSFont.systemFont(ofSize: 100, weight: weight)
    let font = italic ? NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask) : base
    let ct = font as CTFont
    var character: UniChar = 69
    var glyph: CGGlyph = 0
    precondition(CTFontGetGlyphsForCharacters(ct, &character, &glyph, 1))
    let outline = CTFontCreatePathForGlyph(ct, glyph, nil)!
    var guides = ""
    var symbols = ""
    for (scale, factor, baseline) in [("S", 0.8, 696.0), ("M", 1.0, 1126.0), ("L", 1.2, 1556.0)] {
        var transform = CGAffineTransform(a: factor, b: 0, c: 0, d: -factor, tx: 0, ty: 0)
        let path = outline.copy(using: &transform)!
        var commands: [String] = []
        path.applyWithBlock { pointer in
            let e = pointer.pointee
            func point(_ i: Int) -> String { "\(e.points[i].x) \(e.points[i].y)" }
            switch e.type {
            case .moveToPoint: commands.append("M" + point(0))
            case .addLineToPoint: commands.append("L" + point(0))
            case .addQuadCurveToPoint: commands.append("Q" + point(0) + " " + point(1))
            case .addCurveToPoint: commands.append("C" + point(0) + " " + point(1) + " " + point(2))
            case .closeSubpath: commands.append("Z")
            @unknown default: fatalError("Unsupported glyph path")
            }
        }
        let x = 1400.0
        let bounds = path.boundingBoxOfPath
        guides += "<line id=\"Baseline-\(scale)\" x1=\"263\" x2=\"3036\" y1=\"\(baseline)\" y2=\"\(baseline)\"/>\n"
        let capline = baseline - CTFontGetCapHeight(ct)
        guides += "<line id=\"Capline-\(scale)\" x1=\"263\" x2=\"3036\" y1=\"\(capline)\" y2=\"\(capline)\"/>\n"
        for (side, offset) in [("left", bounds.minX - 6), ("right", bounds.maxX + 6)] {
            guides += "<line id=\"\(side)-margin-Regular-\(scale)\" x1=\"\(x + offset)\" x2=\"\(x + offset)\" y1=\"\(baseline - 100)\" y2=\"\(baseline + 20)\"/>\n"
        }
        symbols += "<g id=\"Regular-\(scale)\" transform=\"translate(\(x) \(baseline))\"><path d=\"\(commands.joined(separator: " "))\"/></g>\n"
    }
    let svg = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- SPDX-FileCopyrightText: 2026 the Folio Project -->
    <!-- SPDX-License-Identifier: MIT -->
    <svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="3300" height="2200" viewBox="0 0 3300 2200">
    <g id="Notes"><text id="template-version" x="263" y="300">Template v.3.0</text></g>
    <g id="Guides" fill="none" stroke="#27AAE1">\(guides)</g>
    <g id="Symbols" fill="black">\(symbols)</g>
    </svg>
    """
    let folder = URL(fileURLWithPath: directory).appendingPathComponent("\(name).symbolset")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try svg.write(to: folder.appendingPathComponent("\(name).svg"), atomically: true, encoding: .utf8)
    let contents = """
    {"symbols":[{"filename":"\(name).svg","idiom":"universal"}],"info":{"author":"xcode","version":1}}
    """
    try contents.write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}
